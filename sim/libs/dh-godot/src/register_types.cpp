// GDExtension entry point for dh-godot.
#include "dh_policy_net.hpp"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static void dh_initialize(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(dh::DhPolicyNet);
}

static void dh_terminate(ModuleInitializationLevel p_level) {
	(void)p_level;
}

extern "C" {
GDExtensionBool GDE_EXPORT dh_godot_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(dh_initialize);
	init_obj.register_terminator(dh_terminate);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
