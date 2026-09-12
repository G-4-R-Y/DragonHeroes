#include "render_gl.hpp"

#include <GL/gl.h>
#include <GL/glext.h>
#include <GL/glx.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#undef None
#undef Always
#undef Success

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <fstream>

namespace rb {

namespace {
constexpr float kPi = 3.14159265358979f;

// GL 2.0+ entry points via GLX (portable across Mesa/NVIDIA libGL ABIs).
#define RB_GL_FUNCS(X)                                            \
    X(PFNGLCREATESHADERPROC, glCreateShader)                      \
    X(PFNGLSHADERSOURCEPROC, glShaderSource)                      \
    X(PFNGLCOMPILESHADERPROC, glCompileShader)                    \
    X(PFNGLGETSHADERIVPROC, glGetShaderiv)                        \
    X(PFNGLGETSHADERINFOLOGPROC, glGetShaderInfoLog)              \
    X(PFNGLCREATEPROGRAMPROC, glCreateProgram)                    \
    X(PFNGLATTACHSHADERPROC, glAttachShader)                      \
    X(PFNGLLINKPROGRAMPROC, glLinkProgram)                        \
    X(PFNGLGETPROGRAMIVPROC, glGetProgramiv)                      \
    X(PFNGLGETPROGRAMINFOLOGPROC, glGetProgramInfoLog)            \
    X(PFNGLUSEPROGRAMPROC, glUseProgram)                          \
    X(PFNGLDELETESHADERPROC, glDeleteShader)                      \
    X(PFNGLDELETEPROGRAMPROC, glDeleteProgram)                    \
    X(PFNGLGETUNIFORMLOCATIONPROC, glGetUniformLocation)          \
    X(PFNGLUNIFORM1FPROC, glUniform1f)                            \
    X(PFNGLUNIFORM1IPROC, glUniform1i)                            \
    X(PFNGLUNIFORM3FVPROC, glUniform3fv)                          \
    X(PFNGLUNIFORM1FVPROC, glUniform1fv)                          \
    X(PFNGLUNIFORM4FVPROC, glUniform4fv)                          \
    X(PFNGLUNIFORMMATRIX4FVPROC, glUniformMatrix4fv)              \
    X(PFNGLGENVERTEXARRAYSPROC, glGenVertexArrays)                \
    X(PFNGLBINDVERTEXARRAYPROC, glBindVertexArray)                \
    X(PFNGLDELETEVERTEXARRAYSPROC, glDeleteVertexArrays)          \
    X(PFNGLGENBUFFERSPROC, glGenBuffers)                          \
    X(PFNGLBINDBUFFERPROC, glBindBuffer)                          \
    X(PFNGLBUFFERDATAPROC, glBufferData)                          \
    X(PFNGLDELETEBUFFERSPROC, glDeleteBuffers)                    \
    X(PFNGLVERTEXATTRIBPOINTERPROC, glVertexAttribPointer)        \
    X(PFNGLENABLEVERTEXATTRIBARRAYPROC, glEnableVertexAttribArray)

#define RB_DECL(type, name) type p_##name = nullptr;
RB_GL_FUNCS(RB_DECL)
#undef RB_DECL

bool load_gl() {
    bool ok = true;
#define RB_LOAD(type, name)                                                                     \
    p_##name = reinterpret_cast<type>(glXGetProcAddressARB(reinterpret_cast<const GLubyte*>(#name))); \
    if (!p_##name) { std::fprintf(stderr, "[gl] missing %s\n", #name); ok = false; }
    RB_GL_FUNCS(RB_LOAD)
#undef RB_LOAD
    return ok;
}

struct Mat4 {
    float m[16];   // column-major
    static Mat4 identity() { Mat4 r{}; for (int i = 0; i < 4; ++i) r.m[i * 5] = 1; return r; }
    static Mat4 perspective(float fovy, float aspect, float zn, float zf) {
        Mat4 r{}; float f = 1.f / std::tan(fovy / 2);
        r.m[0] = f / aspect; r.m[5] = f; r.m[10] = (zf + zn) / (zn - zf); r.m[11] = -1; r.m[14] = 2 * zf * zn / (zn - zf);
        return r;
    }
    static Mat4 look_at(Vec3 eye, Vec3 at, Vec3 up) {
        Vec3 f = at - eye; float fl = length(f); f = f * (1.f / fl);
        Vec3 s{f.y * up.z - f.z * up.y, f.z * up.x - f.x * up.z, f.x * up.y - f.y * up.x}; float sl = length(s); s = s * (1.f / sl);
        Vec3 u{s.y * f.z - s.z * f.y, s.z * f.x - s.x * f.z, s.x * f.y - s.y * f.x};
        Mat4 r = identity();
        r.m[0] = s.x; r.m[4] = s.y; r.m[8] = s.z; r.m[1] = u.x; r.m[5] = u.y; r.m[9] = u.z; r.m[2] = -f.x; r.m[6] = -f.y; r.m[10] = -f.z;
        r.m[12] = -(s.x * eye.x + s.y * eye.y + s.z * eye.z); r.m[13] = -(u.x * eye.x + u.y * eye.y + u.z * eye.z); r.m[14] = f.x * eye.x + f.y * eye.y + f.z * eye.z;
        return r;
    }
    static Mat4 trs(Vec3 t, float yaw, Vec3 s) {
        Mat4 r = identity(); float c = std::cos(yaw), sn = std::sin(yaw);
        r.m[0] = c * s.x; r.m[2] = -sn * s.x; r.m[5] = s.y; r.m[8] = sn * s.z; r.m[10] = c * s.z; r.m[12] = t.x; r.m[13] = t.y; r.m[14] = t.z;
        return r;
    }
    static Mat4 trs_full(Vec3 t, float yaw, float pitch, Vec3 s) {   // yaw about Y then pitch about X (body tilt)
        Mat4 r = trs(t, yaw, s); float cp = std::cos(pitch), sp = std::sin(pitch);
        // post-multiply by rotation about local X
        Mat4 x = identity(); x.m[5] = cp; x.m[6] = sp; x.m[9] = -sp; x.m[10] = cp;
        Mat4 o{}; for (int i = 0; i < 4; ++i) for (int j = 0; j < 4; ++j) { float v = 0; for (int k = 0; k < 4; ++k) v += r.m[k * 4 + j] * x.m[i * 4 + k]; o.m[i * 4 + j] = v; }
        return o;
    }
};

const char* kLitVS = R"(#version 330 core
layout(location=0) in vec3 aPos; layout(location=1) in vec3 aNrm; layout(location=2) in vec3 aCol;
uniform mat4 uProj, uView, uModel;
out vec3 vPos; out vec3 vNrm; out vec3 vCol;
void main(){ vec4 wp = uModel * vec4(aPos,1.0); vPos = wp.xyz; vNrm = mat3(uModel) * aNrm; vCol = aCol; gl_Position = uProj * uView * wp; })";

const char* kLitFS = R"(#version 330 core
in vec3 vPos; in vec3 vNrm; in vec3 vCol; out vec4 oCol;
uniform vec3 uCam, uMoonDir, uMoonCol, uAmbient, uFogCol, uEmissive; uniform float uFogDensity, uAlpha;
uniform int uNumLights; uniform vec3 uLightPos[16]; uniform vec3 uLightCol[16]; uniform float uLightRange[16];
void main(){
  vec3 n = normalize(vNrm); vec3 v = normalize(uCam - vPos);
  vec3 lit = uAmbient * vCol;
  float nd = max(dot(n, -uMoonDir), 0.0); lit += vCol * uMoonCol * nd;
  vec3 hm = normalize(v - uMoonDir); lit += uMoonCol * pow(max(dot(n, hm),0.0), 24.0) * 0.08;
  for (int i = 0; i < uNumLights; ++i) {
    vec3 d = uLightPos[i] - vPos; float dist = length(d); if (dist > uLightRange[i]) continue;
    vec3 l = d / max(dist, 0.001); float x = dist / uLightRange[i];
    float att = (1.0 - x*x) * (1.0 - x*x) / (1.0 + 2.0*dist*dist/(uLightRange[i]*uLightRange[i]));
    float ndl = max(dot(n, l), 0.0);
    vec3 h = normalize(l + v); float spec = pow(max(dot(n,h),0.0), 32.0) * 0.25;
    lit += (vCol * ndl + spec) * uLightCol[i] * att * 2.2;
  }
  lit += uEmissive;
  float fd = length(uCam - vPos); float fog = 1.0 - exp(-fd * uFogDensity);
  vec3 c = mix(lit, uFogCol, fog);
  c = c / (c + vec3(0.55));  // soft tonemap, keeps embers hot
  oCol = vec4(c, uAlpha);
})";

const char* kUnlitVS = R"(#version 330 core
layout(location=0) in vec3 aPos; layout(location=1) in vec3 aNrm; layout(location=2) in vec3 aCol;
uniform mat4 uProj, uView, uModel; out vec3 vCol;
void main(){ vCol = aCol; gl_Position = uProj * uView * uModel * vec4(aPos,1.0); })";

const char* kUnlitFS = R"(#version 330 core
in vec3 vCol; out vec4 oCol; uniform vec3 uColor; uniform float uAlpha;
void main(){ oCol = vec4(uColor * vCol, uAlpha); })";

const char* kUiVS = R"(#version 330 core
layout(location=0) in vec2 aPos; uniform vec4 uRect; // x,y,w,h in [0,1]
void main(){ vec2 p = uRect.xy + aPos * uRect.zw; gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0); })";
const char* kUiFS = R"(#version 330 core
out vec4 oCol; uniform vec4 uColor; void main(){ oCol = uColor; })";

GLuint compile(GLenum type, const char* src) {
    GLuint sh = p_glCreateShader(type);
    p_glShaderSource(sh, 1, &src, nullptr);
    p_glCompileShader(sh);
    GLint ok = 0; p_glGetShaderiv(sh, GL_COMPILE_STATUS, &ok);
    if (!ok) { char log[2048]; p_glGetShaderInfoLog(sh, sizeof log, nullptr, log); std::fprintf(stderr, "[gl] shader: %s\n", log); }
    return sh;
}
GLuint program(const char* vs, const char* fs) {
    GLuint p = p_glCreateProgram(), v = compile(GL_VERTEX_SHADER, vs), f = compile(GL_FRAGMENT_SHADER, fs);
    p_glAttachShader(p, v); p_glAttachShader(p, f); p_glLinkProgram(p);
    GLint ok = 0; p_glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) { char log[2048]; p_glGetProgramInfoLog(p, sizeof log, nullptr, log); std::fprintf(stderr, "[gl] link: %s\n", log); }
    p_glDeleteShader(v); p_glDeleteShader(f);
    return p;
}

struct GpuMesh {
    GLuint vao = 0, vbo = 0, ebo = 0; GLsizei count = 0;
    void upload(const MeshData& m) {
        if (!vao) { p_glGenVertexArrays(1, &vao); p_glGenBuffers(1, &vbo); p_glGenBuffers(1, &ebo); }
        p_glBindVertexArray(vao);
        p_glBindBuffer(GL_ARRAY_BUFFER, vbo);
        p_glBufferData(GL_ARRAY_BUFFER, static_cast<GLsizeiptr>(m.verts.size() * sizeof(Vertex)), m.verts.data(), GL_STATIC_DRAW);
        p_glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
        p_glBufferData(GL_ELEMENT_ARRAY_BUFFER, static_cast<GLsizeiptr>(m.idx.size() * 4), m.idx.data(), GL_STATIC_DRAW);
        for (GLuint i = 0; i < 3; ++i) {
            p_glEnableVertexAttribArray(i);
            p_glVertexAttribPointer(i, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), reinterpret_cast<const void*>(static_cast<size_t>(i) * 12));
        }
        count = static_cast<GLsizei>(m.idx.size());
        p_glBindVertexArray(0);
    }
    void draw() const { p_glBindVertexArray(vao); glDrawElements(GL_TRIANGLES, count, GL_UNSIGNED_INT, nullptr); p_glBindVertexArray(0); }
    void destroy() { if (vao) { p_glDeleteVertexArrays(1, &vao); p_glDeleteBuffers(1, &vbo); p_glDeleteBuffers(1, &ebo); vao = 0; } }
};

struct Ring { bool active = false; Vec3 pos; float radius, t, dur; std::array<float, 3> col; int serial; };
struct Cone { bool active = false; Vec3 pos; float yaw, range, t, dur; std::array<float, 3> col; int serial; };
struct FieldFx { bool active = false; Vec3 pos; float radius, t, dur; };
struct MeteorFx { bool active = false; Vec3 from, to; float t, dur; };
struct SparkFx { bool active = false; Vec3 pos; float t; std::array<float, 3> col; };
struct SlashFx { bool active = false; Vec3 pos; float yaw, reach, t; std::array<float, 3> col; };
} // namespace

// --- Camera (same rig as godot3d/scripts/camera_rig.gd) ------------------------------

void Camera::update(const State& s, float alpha, const Heightfield& hf, float dt, bool locked) {
    Vec3 hp = lerp(s.hunter.prev, s.hunter.pos, alpha);
    Vec3 dp = lerp(s.dragon.prev, s.dragon.pos, alpha);
    Vec3 f = hp + Vec3{0, 1.6f, 0};
    float d = dist, p = pitch;
    if (locked && s.dragon.state != DragonState::Dead) {
        Vec3 to = dp - hp; to.y = 0;
        Vec3 back = normalize_xz(to) * -1.f;
        float want = std::atan2(back.x, back.z);
        yaw += angle_diff(yaw, want) * (1.f - std::exp(-dt * 4.f));
        f = hp + to * 0.22f + Vec3{0, 1.8f, 0};
        d = 7.5f + std::clamp(length_xz(to) * 0.12f, 0.f, 4.f);
        p = -0.30f;
    }
    Vec3 back_dir{std::sin(yaw), 0, std::cos(yaw)};
    Vec3 want = f + back_dir * (d * std::cos(p)) + Vec3{0, -std::sin(p) * d, 0};
    want.y = std::max(want.y, hf.height_at(want.x, want.z) + 0.7f);
    if (!started) { pos = want; focus = f; started = true; }
    pos = lerp(pos, want, 1.f - std::exp(-dt * 9.f));
    focus = lerp(focus, f, 1.f - std::exp(-dt * 12.f));
}

// --- Renderer -----------------------------------------------------------------------------------

struct Renderer::Impl {
    Display* dpy = nullptr;
    Window win = 0;
    GLXContext ctx = nullptr;
    Colormap cmap = 0;
    Atom wm_delete = 0;
    GLuint lit = 0, unlit = 0, ui = 0, ui_vao = 0, ui_vbo = 0;
    GpuMesh terrain, rocks, props, hunter, dragon, pet, ring, sector, disc, sphere;
    std::vector<Valley::Prop> world_lights;
    std::array<Ring, 16> rings{}; std::array<Cone, 4> cones{}; std::array<FieldFx, 8> fields{};
    std::array<MeteorFx, 8> meteors{}; std::array<SparkFx, 10> sparks{}; std::array<SlashFx, 3> slashes{};
    int serial = 0;
    float toast_t = 0, enrage_t = 0;
    bool grabbed = false;
    int cx = 0, cy = 0;
    bool have_center = false;
};

Renderer::Renderer(int w, int h, const std::string& title) : p_(std::make_unique<Impl>()), w_(w), h_(h) {
    Impl& I = *p_;
    I.dpy = XOpenDisplay(nullptr);
    if (!I.dpy) { std::fprintf(stderr, "[x11] no display\n"); return; }
    static int attribs[] = {GLX_X_RENDERABLE, 1, GLX_DRAWABLE_TYPE, GLX_WINDOW_BIT, GLX_RENDER_TYPE, GLX_RGBA_BIT,
        GLX_RED_SIZE, 8, GLX_GREEN_SIZE, 8, GLX_BLUE_SIZE, 8, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, 1, 0};
    int n = 0;
    GLXFBConfig* fbc = glXChooseFBConfig(I.dpy, DefaultScreen(I.dpy), attribs, &n);
    if (!fbc || n == 0) { std::fprintf(stderr, "[glx] no fbconfig\n"); return; }
    GLXFBConfig fb = fbc[0];
    XFree(fbc);
    XVisualInfo* vi = glXGetVisualFromFBConfig(I.dpy, fb);
    if (!vi) { std::fprintf(stderr, "[glx] no visual\n"); return; }
    Window root = RootWindow(I.dpy, vi->screen);
    I.cmap = XCreateColormap(I.dpy, root, vi->visual, AllocNone);
    XSetWindowAttributes swa{};
    swa.colormap = I.cmap;
    swa.event_mask = KeyPressMask | KeyReleaseMask | PointerMotionMask | ButtonPressMask | StructureNotifyMask;
    I.win = XCreateWindow(I.dpy, root, 100, 100, static_cast<unsigned>(w), static_cast<unsigned>(h), 0, vi->depth, InputOutput, vi->visual, CWColormap | CWEventMask, &swa);
    XFree(vi);
    XStoreName(I.dpy, I.win, title.c_str());
    I.wm_delete = XInternAtom(I.dpy, "WM_DELETE_WINDOW", 0);
    XSetWMProtocols(I.dpy, I.win, &I.wm_delete, 1);
    XMapWindow(I.dpy, I.win);
    using CreateCtx = GLXContext (*)(Display*, GLXFBConfig, GLXContext, int, const int*);
    auto create = reinterpret_cast<CreateCtx>(glXGetProcAddressARB(reinterpret_cast<const GLubyte*>("glXCreateContextAttribsARB")));
    if (create) {
        int cattr[] = {GLX_CONTEXT_MAJOR_VERSION_ARB, 3, GLX_CONTEXT_MINOR_VERSION_ARB, 3, GLX_CONTEXT_PROFILE_MASK_ARB, GLX_CONTEXT_CORE_PROFILE_BIT_ARB, 0};
        I.ctx = create(I.dpy, fb, nullptr, 1, cattr);
    }
    if (!I.ctx) I.ctx = glXCreateNewContext(I.dpy, fb, GLX_RGBA_TYPE, nullptr, 1);
    if (!I.ctx) { std::fprintf(stderr, "[glx] no context\n"); return; }
    glXMakeCurrent(I.dpy, I.win, I.ctx);
    if (!load_gl()) return;
    const GLubyte* rs = glGetString(GL_RENDERER);
    const GLubyte* vs = glGetString(GL_VERSION);
    gl_renderer_ = std::string(rs ? reinterpret_cast<const char*>(rs) : "?") + " · GL " + (vs ? reinterpret_cast<const char*>(vs) : "?");
    using SwapInterval = void (*)(Display*, GLXDrawable, int);
    auto swap_interval = reinterpret_cast<SwapInterval>(glXGetProcAddressARB(reinterpret_cast<const GLubyte*>("glXSwapIntervalEXT")));
    if (swap_interval) swap_interval(I.dpy, I.win, 1);
    I.lit = program(kLitVS, kLitFS);
    I.unlit = program(kUnlitVS, kUnlitFS);
    I.ui = program(kUiVS, kUiFS);
    static const float quad[] = {0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 1};
    p_glGenVertexArrays(1, &I.ui_vao); p_glGenBuffers(1, &I.ui_vbo);
    p_glBindVertexArray(I.ui_vao); p_glBindBuffer(GL_ARRAY_BUFFER, I.ui_vbo);
    p_glBufferData(GL_ARRAY_BUFFER, sizeof quad, quad, GL_STATIC_DRAW);
    p_glEnableVertexAttribArray(0); p_glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 8, nullptr);
    p_glBindVertexArray(0);
    I.ring.upload(unit_ring()); I.sector.upload(unit_sector(35.f)); I.disc.upload(unit_disc()); I.sphere.upload(unit_sphere());
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    ok_ = true;
}

Renderer::~Renderer() {
    Impl& I = *p_;
    if (I.ctx) {
        for (GpuMesh* m : {&I.terrain, &I.rocks, &I.props, &I.hunter, &I.dragon, &I.pet, &I.ring, &I.sector, &I.disc, &I.sphere}) m->destroy();
        if (I.lit) p_glDeleteProgram(I.lit);
        if (I.unlit) p_glDeleteProgram(I.unlit);
        if (I.ui) p_glDeleteProgram(I.ui);
        glXMakeCurrent(I.dpy, 0, nullptr);
        glXDestroyContext(I.dpy, I.ctx);
    }
    if (I.dpy) {
        if (I.win) XDestroyWindow(I.dpy, I.win);
        if (I.cmap) XFreeColormap(I.dpy, I.cmap);
        XCloseDisplay(I.dpy);
    }
}

void Renderer::poll(KeyState& k) {
    Impl& I = *p_;
    k.dodge = k.attack = k.skill = k.pet = k.lock = k.rematch = false;
    k.mouse_dx = k.mouse_dy = 0;
    while (XPending(I.dpy)) {
        XEvent e; XNextEvent(I.dpy, &e);
        if (e.type == ClientMessage && static_cast<Atom>(e.xclient.data.l[0]) == I.wm_delete) k.quit = true;
        else if (e.type == KeyPress || e.type == KeyRelease) {
            bool down = e.type == KeyPress;
            KeySym ks = XLookupKeysym(&e.xkey, 0);
            switch (ks) {
                case XK_w: case XK_Up: k.w = down; break;
                case XK_s: case XK_Down: k.s = down; break;
                case XK_a: case XK_Left: k.a = down; break;
                case XK_d: case XK_Right: k.d = down; break;
                case XK_space: case XK_Shift_L: if (down) k.dodge = true; break;
                case XK_j: if (down) k.attack = true; break;
                case XK_k: if (down) k.skill = true; break;
                case XK_e: if (down) k.pet = true; break;
                case XK_Tab: case XK_q: if (down) k.lock = true; break;
                case XK_r: if (down) k.rematch = true; break;
                case XK_Escape: if (down) { if (I.grabbed) { XUngrabPointer(I.dpy, CurrentTime); I.grabbed = false; } else k.quit = true; } break;
                default: break;
            }
        } else if (e.type == ButtonPress) {
            if (e.xbutton.button == Button1) { if (I.grabbed) k.attack = true; else k.grab_request = true; }
            else if (e.xbutton.button == Button3 && I.grabbed) k.skill = true;
            else if (e.xbutton.button == Button2 && I.grabbed) k.lock = true;
        } else if (e.type == MotionNotify && I.grabbed) {
            if (I.have_center) { k.mouse_dx += e.xmotion.x - I.cx; k.mouse_dy += e.xmotion.y - I.cy; }
            I.cx = w_ / 2; I.cy = h_ / 2; I.have_center = true;
            XWarpPointer(I.dpy, 0, I.win, 0, 0, 0, 0, I.cx, I.cy);
        } else if (e.type == ConfigureNotify) {
            w_ = e.xconfigure.width; h_ = e.xconfigure.height;
        }
    }
    if (k.grab_request) {
        k.grab_request = false;
        if (XGrabPointer(I.dpy, I.win, 1, PointerMotionMask | ButtonPressMask, GrabModeAsync, GrabModeAsync, I.win, 0, CurrentTime) == GrabSuccess) {
            I.grabbed = true; I.have_center = false;
        }
    }
}

void Renderer::upload_world(const Valley& v, const std::vector<Valley::Prop>& lights) {
    Impl& I = *p_;
    I.terrain.upload(v.terrain());
    I.rocks.upload(v.rocks());
    I.props.upload(v.props(lights));
    I.world_lights = lights;
}

void Renderer::set_creatures(const MeshData& h, const MeshData& d, const MeshData& p) {
    p_->hunter.upload(h); p_->dragon.upload(d); p_->pet.upload(p);
}

namespace {
template <class T, size_t N> T& acquire(std::array<T, N>& pool, int& overflow) {
    for (auto& e : pool) if (!e.active) return e;
    overflow++;
    return pool[0];
}
} // namespace

void Renderer::consume_events(State& s) {
    Impl& I = *p_;
    for (const Event& e : s.events) {
        switch (e.kind) {
            case Event::Ring: { Ring& r = acquire(I.rings, overflow_); r = {true, e.pos, e.a, 0.f, e.b, e.color, ++I.serial}; break; }
            case Event::Cone: { Cone& c = acquire(I.cones, overflow_); c = {true, e.pos, e.a, e.b, 0.f, e.c, e.color, ++I.serial}; break; }
            case Event::ConeEnd: for (auto& c : I.cones) c.active = false; break;
            case Event::RingEnd: for (auto& r : I.rings) if (r.dur > 1.0f) r.active = false; break;   // telegraph rings only (flashes are short)
            case Event::Field: { FieldFx& f = acquire(I.fields, overflow_); f = {true, e.pos, e.a, 0.f, e.b}; break; }
            case Event::MeteorFall: { MeteorFx& m = acquire(I.meteors, overflow_); m = {true, e.pos + Vec3{-6.f, 34.f, 4.f}, e.pos, 0.f, e.a}; break; }
            case Event::Spark: { SparkFx& sp = acquire(I.sparks, overflow_); sp = {true, e.pos, 0.f, e.color}; break; }
            case Event::Slash: { SlashFx& sl = acquire(I.slashes, overflow_); sl = {true, e.pos, e.a, e.b, 0.f, e.color}; break; }
            case Event::Toast: I.toast_t = 3.5f; std::printf("[toast] %s\n", e.text.c_str()); break;
            case Event::Enrage: I.enrage_t = 1.0f; break;
            case Event::Slain: case Event::Rematch: for (auto& c : I.cones) c.active = false; for (auto& r : I.rings) r.active = false; for (auto& f : I.fields) f.active = false; break;
        }
    }
    s.events.clear();
}

void Renderer::frame(const State& s, float alpha, const Camera& cam, double time, float dt) {
    Impl& I = *p_;
    glViewport(0, 0, w_, h_);
    glClearColor(0.015f, 0.02f, 0.06f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glDepthMask(GL_TRUE); glDisable(GL_BLEND);
    Mat4 proj = Mat4::perspective(62.f * kPi / 180.f, static_cast<float>(w_) / static_cast<float>(h_), 0.1f, 400.f);
    Mat4 view = Mat4::look_at(cam.pos, cam.focus, {0, 1, 0});
    // advance vfx
    for (auto& r : I.rings) if (r.active) { r.t += dt; if (r.dur > 0 && r.t >= r.dur) r.active = false; }
    for (auto& c : I.cones) if (c.active) { c.t += dt; if (c.dur > 0 && c.t >= c.dur) c.active = false; }
    for (auto& f : I.fields) if (f.active) { f.t += dt; if (f.t >= f.dur) f.active = false; }
    for (auto& m : I.meteors) if (m.active) { m.t += dt; if (m.t >= m.dur + 0.05f) m.active = false; }
    for (auto& sp : I.sparks) if (sp.active) { sp.t += dt; if (sp.t >= 0.45f) sp.active = false; }
    for (auto& sl : I.slashes) if (sl.active) { sl.t += dt; if (sl.t >= 0.14f) sl.active = false; }
    I.toast_t = std::max(I.toast_t - dt, 0.f); I.enrage_t = std::max(I.enrage_t - dt, 0.f);
    // lights: world + dynamic, nearest 16 to the focus
    Vec3 hp = lerp(s.hunter.prev, s.hunter.pos, alpha), dp = lerp(s.dragon.prev, s.dragon.pos, alpha), pp = lerp(s.pet.prev, s.pet.pos, alpha);
    std::vector<PointLight> lights;
    for (const auto& wl : I.world_lights) {
        float e = wl.energy;
        if (wl.pit) e += std::sin(static_cast<float>(time) * 9.f + wl.pos.x) * 0.35f + std::sin(static_cast<float>(time) * 23.f + wl.pos.z) * 0.18f;
        lights.push_back({wl.pos + Vec3{0, wl.pit ? 1.4f : 0.9f, 0}, wl.color * e, wl.range});
    }
    lights.push_back({hp + Vec3{-0.5f, 1.3f, 0}, Vec3{1.f, 0.72f, 0.4f} * 1.6f, 9.f});          // lantern
    lights.push_back({dp + forward(s.dragon.yaw) * 5.6f + Vec3{0, 4.2f + s.dragon.body_y, 0}, Vec3{1.f, 0.5f, 0.15f} * 1.4f, 7.f});   // maw
    if (s.dragon.enraged) lights.push_back({dp + Vec3{0, 2.5f, 0}, Vec3{1.f, 0.15f, 0.05f} * (2.4f + std::sin(static_cast<float>(time) * 11.f) * 0.5f), 11.f});
    for (const auto& f : I.fields) if (f.active) { float life = 1.f - f.t / f.dur; lights.push_back({f.pos + Vec3{0, 1.2f, 0}, Vec3{1.f, 0.5f, 0.15f} * ((2.2f + 1.2f * life) + std::sin(f.t * 17.f) * 0.4f), f.radius * 3.5f + 3.f}); }
    for (const auto& m : I.meteors) if (m.active) { float k = std::clamp(m.t / m.dur, 0.f, 1.f); lights.push_back({lerp(m.from, m.to, k * k), Vec3{1.f, 0.5f, 0.2f} * 2.5f, 12.f}); }
    if (s.loop == Loop::Drop) lights.push_back({dp + Vec3{0, 2.f, 0}, Vec3{1.f, 0.85f, 0.4f} * (2.5f + std::sin(s.loop_t * 6.f) * 1.2f), 14.f});
    std::sort(lights.begin(), lights.end(), [&](const PointLight& a, const PointLight& b) { return length(a.pos - cam.focus) < length(b.pos - cam.focus); });
    if (lights.size() > 16) lights.resize(16);
    std::vector<float> lp, lc, lr;
    for (const auto& l : lights) { lp.insert(lp.end(), {l.pos.x, l.pos.y, l.pos.z}); lc.insert(lc.end(), {l.color.x, l.color.y, l.color.z}); lr.push_back(l.range); }
    // lit pass
    p_glUseProgram(I.lit);
    auto U = [&](const char* n) { return p_glGetUniformLocation(I.lit, n); };
    p_glUniformMatrix4fv(U("uProj"), 1, GL_FALSE, proj.m);
    p_glUniformMatrix4fv(U("uView"), 1, GL_FALSE, view.m);
    float camv[3] = {cam.pos.x, cam.pos.y, cam.pos.z}; p_glUniform3fv(U("uCam"), 1, camv);
    Vec3 moon{-std::sin(35.f * kPi / 180.f) * std::cos(48.f * kPi / 180.f), -std::sin(48.f * kPi / 180.f), -std::cos(35.f * kPi / 180.f) * std::cos(48.f * kPi / 180.f)};
    float moonv[3] = {moon.x, moon.y, moon.z}; p_glUniform3fv(U("uMoonDir"), 1, moonv);
    float mooncol[3] = {0.55f * 0.85f, 0.62f * 0.85f, 0.88f * 0.85f}; p_glUniform3fv(U("uMoonCol"), 1, mooncol);
    float amb[3] = {0.28f * 0.55f, 0.32f * 0.55f, 0.50f * 0.55f}; p_glUniform3fv(U("uAmbient"), 1, amb);
    float fog[3] = {0.05f, 0.07f, 0.14f}; p_glUniform3fv(U("uFogCol"), 1, fog);
    p_glUniform1f(U("uFogDensity"), 0.010f);
    p_glUniform1i(U("uNumLights"), static_cast<GLint>(lights.size()));
    if (!lights.empty()) { p_glUniform3fv(U("uLightPos"), static_cast<GLint>(lights.size()), lp.data()); p_glUniform3fv(U("uLightCol"), static_cast<GLint>(lights.size()), lc.data()); p_glUniform1fv(U("uLightRange"), static_cast<GLint>(lights.size()), lr.data()); }
    p_glUniform1f(U("uAlpha"), 1.f);
    float zero[3] = {0, 0, 0};
    auto draw_lit = [&](const GpuMesh& m, const Mat4& model, const float* emissive) {
        p_glUniformMatrix4fv(U("uModel"), 1, GL_FALSE, model.m);
        p_glUniform3fv(U("uEmissive"), 1, emissive);
        m.draw();
    };
    draw_lit(I.terrain, Mat4::identity(), zero);
    draw_lit(I.rocks, Mat4::identity(), zero);
    float prop_em[3] = {0.35f, 0.3f, 0.12f};
    draw_lit(I.props, Mat4::identity(), prop_em);
    // creatures
    float hunter_tilt = s.hunter.state == HunterState::Dodge ? -std::sin(s.hunter.t / Hunter::kDodgeDur * kPi) * 0.9f : (s.hunter.state == HunterState::Skill ? -0.3f : 0.f);
    draw_lit(I.hunter, Mat4::trs_full(hp, s.hunter.yaw, hunter_tilt, {1, 1, 1}), zero);
    float dragon_em[3] = {0, 0, 0};
    if (s.dragon.enraged) { dragon_em[0] = 0.6f * 0.9f; dragon_em[1] = 0.05f * 0.9f; dragon_em[2] = 0.02f * 0.9f; }
    if (I.enrage_t > 0) { dragon_em[0] += I.enrage_t; dragon_em[1] += I.enrage_t * 0.2f; }
    Vec3 dscale{1, 1, 1};
    if (s.dragon.state == DragonState::Dead) dscale.y = std::max(0.25f, 1.f - s.loop_t * 0.75f);
    draw_lit(I.dragon, Mat4::trs(dp + Vec3{0, s.dragon.body_y, 0}, s.dragon.yaw, dscale), dragon_em);
    draw_lit(I.pet, Mat4::trs(pp, s.pet.yaw, {1, 1, 1}), zero);
    // fields (emissive discs)
    for (const auto& f : I.fields) if (f.active) { float life = 1.f - f.t / f.dur; float em[3] = {1.0f * (0.6f + life), 0.4f * (0.6f + life), 0.08f}; draw_lit(I.disc, Mat4::trs(f.pos + Vec3{0, 0.05f, 0}, 0, {f.radius, 1, f.radius}), em); }
    for (const auto& m : I.meteors) if (m.active) { float k = std::clamp(m.t / m.dur, 0.f, 1.f); float em[3] = {1.f, 0.45f, 0.1f}; draw_lit(I.sphere, Mat4::trs(lerp(m.from, m.to, k * k), 0, {0.7f, 0.7f, 0.7f}), em); }
    // unlit additive pass: telegraphs
    glEnable(GL_BLEND); glBlendFunc(GL_SRC_ALPHA, GL_ONE); glDepthMask(GL_FALSE); glDisable(GL_CULL_FACE); glDisable(GL_DEPTH_TEST);
    p_glUseProgram(I.unlit);
    auto V = [&](const char* n) { return p_glGetUniformLocation(I.unlit, n); };
    p_glUniformMatrix4fv(V("uProj"), 1, GL_FALSE, proj.m);
    p_glUniformMatrix4fv(V("uView"), 1, GL_FALSE, view.m);
    auto draw_unlit = [&](const GpuMesh& m, const Mat4& model, std::array<float, 3> col, float a) {
        p_glUniformMatrix4fv(V("uModel"), 1, GL_FALSE, model.m); p_glUniform3fv(V("uColor"), 1, col.data()); p_glUniform1f(V("uAlpha"), a); m.draw();
    };
    for (const auto& r : I.rings) if (r.active) { float pulse = 0.65f + 0.35f * std::sin(r.t * 14.f); draw_unlit(I.ring, Mat4::trs(r.pos + Vec3{0, 0.12f, 0}, 0, {r.radius, 1, r.radius}), r.col, (r.dur > 1.f ? 0.5f : 0.9f) * pulse); }
    for (const auto& c : I.cones) if (c.active) { float k = std::clamp(c.t / std::max(c.dur, 0.01f), 0.f, 1.f); draw_unlit(I.sector, Mat4::trs(c.pos + Vec3{0, 0.14f, 0}, c.yaw, {c.range, 1, c.range}), c.col, 0.35f * (0.5f + 0.5f * k)); }
    for (const auto& sl : I.slashes) if (sl.active) draw_unlit(I.sector, Mat4::trs(sl.pos + Vec3{0, 1.1f, 0}, sl.yaw, {sl.reach, 1, sl.reach}), sl.col, 0.6f * (1.f - sl.t / 0.14f));
    for (const auto& sp : I.sparks) if (sp.active) { float k = sp.t / 0.45f; draw_unlit(I.ring, Mat4::trs(sp.pos, 0, {0.3f + k * 1.4f, 1, 0.3f + k * 1.4f}), sp.col, 0.9f * (1.f - k)); }
    glEnable(GL_DEPTH_TEST); glEnable(GL_CULL_FACE); glDepthMask(GL_TRUE);
    // UI: bars (no text in the raw client — numbers go to stdout)
    glDisable(GL_DEPTH_TEST); glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    p_glUseProgram(I.ui);
    p_glBindVertexArray(I.ui_vao);
    auto rect = [&](float x, float y, float w, float h, float r, float g, float b, float a) {
        float rc[4] = {x, y, w, h}, cc[4] = {r, g, b, a};
        p_glUniform4fv(p_glGetUniformLocation(I.ui, "uRect"), 1, rc);
        p_glUniform4fv(p_glGetUniformLocation(I.ui, "uColor"), 1, cc);
        glDrawArrays(GL_TRIANGLES, 0, 6);
    };
    rect(0.02f, 0.93f, 0.24f, 0.025f, 0.05f, 0.05f, 0.07f, 0.85f);
    rect(0.022f, 0.932f, 0.236f * std::clamp(s.hunter.hp / Hunter::kHpMax, 0.f, 1.f), 0.021f, 0.75f, 0.15f, 0.1f, 1.f);
    for (int i = 0; i < Hunter::kDodgeCharges; ++i) { bool on = i < s.hunter.dodge_charges; rect(0.02f + i * 0.018f, 0.90f, 0.014f, 0.012f, on ? 0.45f : 0.2f, on ? 0.8f : 0.25f, on ? 1.f : 0.3f, 1.f); }
    rect(0.30f, 0.94f, 0.40f, 0.02f, 0.05f, 0.05f, 0.07f, 0.85f);
    bool en = s.dragon.enraged;
    rect(0.302f, 0.942f, 0.396f * std::clamp(s.dragon.hp / Dragon::kHpMax, 0.f, 1.f), 0.016f, en ? 0.85f : 0.7f, en ? 0.35f : 0.55f, en ? 0.1f : 0.15f, 1.f);
    if (s.dragon.punishable) rect(0.48f, 0.90f, 0.04f, 0.02f, 0.5f, 1.f, 0.6f, 0.9f);
    if (s.dragon.state == DragonState::Tele) rect(0.48f, 0.90f, 0.04f, 0.02f, 1.f, 0.5f, 0.2f, 0.6f + 0.4f * std::sin(static_cast<float>(time) * 20.f));
    if (s.hunter.skill_cd <= 0.f) rect(0.02f, 0.87f, 0.03f, 0.012f, 1.f, 0.7f, 0.35f, 1.f);
    if (s.pet.howl_cd <= 0.f) rect(0.055f, 0.87f, 0.03f, 0.012f, 0.4f, 1.f, 0.9f, 1.f);
    if (I.toast_t > 0) { float a = std::clamp(I.toast_t / 0.6f, 0.f, 1.f); rect(0.25f, 0.47f, 0.5f, 0.07f, 0.05f, 0.03f, 0.02f, 0.8f * a); rect(0.27f, 0.49f, 0.46f, 0.03f, 1.f, 0.85f, 0.4f, a); }
    p_glBindVertexArray(0);
    glEnable(GL_DEPTH_TEST); glDisable(GL_BLEND);
}

void Renderer::swap() { glXSwapBuffers(p_->dpy, p_->win); }

bool Renderer::read_ppm(const std::string& path) {
    std::vector<unsigned char> px(static_cast<size_t>(w_) * static_cast<size_t>(h_) * 3);
    glReadBuffer(GL_BACK);
    glReadPixels(0, 0, w_, h_, GL_RGB, GL_UNSIGNED_BYTE, px.data());
    std::ofstream f(path, std::ios::binary);
    if (!f) return false;
    f << "P6\n" << w_ << " " << h_ << "\n255\n";
    for (int y = h_ - 1; y >= 0; --y) f.write(reinterpret_cast<const char*>(px.data() + static_cast<size_t>(y) * static_cast<size_t>(w_) * 3), static_cast<std::streamsize>(w_) * 3);
    return static_cast<bool>(f);
}

} // namespace rb
