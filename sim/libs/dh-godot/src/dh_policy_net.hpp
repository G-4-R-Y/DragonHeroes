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
	void clear_layers();
	// w is row-major [n_out * n_in]; b is [n_out]. Rejects a mismatched size
	// rather than reading past the end.
	bool add_layer(const godot::PackedFloat64Array &w, const godot::PackedFloat64Array &b,
			int64_t n_in, int64_t n_out, bool use_tanh);
	godot::PackedFloat64Array forward(const godot::PackedFloat64Array &x) const;
	int64_t layer_count() const;

private:
	struct Layer {
		std::vector<double> w;
		std::vector<double> b;
		int64_t n_in = 0;
		int64_t n_out = 0;
		bool tanh_act = true;
	};
	std::vector<Layer> layers_;
	// Scratch buffers: a forward pass runs 60 times a second per fighter, so it
	// must not allocate.
	mutable std::vector<double> cur_;
	mutable std::vector<double> nxt_;
};

} // namespace dh
