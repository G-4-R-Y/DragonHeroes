// dh-godot — the arena policy forward pass, in C++.
//
// WHY THIS EXISTS (measured 2026-09-13): the same forward pass in GDScript cost
// ~2,200 us per fighter per tick — 93% of the entire arena tick, against ~7% for
// physics, projectiles, fields and every other node combined. The net is tiny
// (47-64-64-10, 7,744 multiply-adds); GDScript was simply spending ~400 ns on
// each one. Flattening the GDScript version bought 1.74x and left it ~1000x off
// what C does, which is what this closes.
//
// SCOPE (canon 10): this is math, not gameplay. It holds no rules, reads no
// files and knows nothing about fighters — GDScript still parses the
// arena.policy.v1 JSON and pushes the flattened weights in. That keeps the
// loading path, and its error handling, exactly where it was.
//
// BIT-EXACTNESS IS A REQUIREMENT, not a nicety: nets in the registry were
// trained against the GDScript runtime, so a different answer here would
// silently change every deployed policy. The loop below therefore accumulates
// in the SAME order, in double, with -ffp-contract=off inherited from the sim
// build (no FMA contraction) and no fast-math, and uses libm tanh() exactly as
// GDScript's tanh() does.
//
// ACTIVATIONS (Ricardo, 2026-09-13: "net hyperparams should be configurable, as
// to test new architectures"). The layer used to carry a single bool, use_tanh,
// because every net was tanh. It now carries an activation CODE, shared with
// ml/training/arch.py and game/arena/neural_policy.gd:
//
//     0 linear   1 tanh   2 relu   3 leaky_relu (slope 0.01)
//
// The numbering is not arbitrary: a Variant bool coerces to 0/1, so the old
// add_layer(..., true/false) calls still mean exactly what they meant.
//
// The set is deliberately tiny. Each one has to be EXACTLY reproducible in both
// GDScript and C++ or the two arena paths disagree in the last bit and every
// trained weight is invalidated; max(0,x) and a hard-coded 0.01 slope are,
// erf/exp curves are a proof nobody has written.
#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

#include <cstdint>
#include <vector>

namespace dh {

class DhPolicyNet : public godot::RefCounted {
	GDCLASS(DhPolicyNet, godot::RefCounted)

protected:
	static void _bind_methods();

public:
	enum Activation : int64_t { ACT_LINEAR = 0, ACT_TANH = 1, ACT_RELU = 2, ACT_LEAKY_RELU = 3 };
	static constexpr double kLeakySlope = 0.01;

	void clear_layers();
	// w is row-major [n_out * n_in]; b is [n_out]. Rejects a mismatched size
	// rather than reading past the end, and an activation code it does not know
	// rather than quietly running a different net.
	bool add_layer(const godot::PackedFloat64Array &w, const godot::PackedFloat64Array &b,
			int64_t n_in, int64_t n_out, int64_t act);
	godot::PackedFloat64Array forward(const godot::PackedFloat64Array &x) const;
	int64_t layer_count() const;

private:
	struct Layer {
		std::vector<double> w;
		std::vector<double> b;
		int64_t n_in = 0;
		int64_t n_out = 0;
		int64_t act = ACT_TANH;
	};
	std::vector<Layer> layers_;
	// Scratch buffers: a forward pass runs 60 times a second per fighter, so it
	// must not allocate.
	mutable std::vector<double> cur_;
	mutable std::vector<double> nxt_;
};

} // namespace dh
