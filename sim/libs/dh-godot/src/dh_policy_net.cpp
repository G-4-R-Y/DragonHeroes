#include "dh_policy_net.hpp"

#include <godot_cpp/core/class_db.hpp>

#include <algorithm>
#include <cmath>

using namespace godot;

namespace dh {

void DhPolicyNet::_bind_methods() {
	ClassDB::bind_method(D_METHOD("clear_layers"), &DhPolicyNet::clear_layers);
	ClassDB::bind_method(D_METHOD("add_layer", "w", "b", "n_in", "n_out", "act"),
			&DhPolicyNet::add_layer);
	ClassDB::bind_method(D_METHOD("forward", "x"), &DhPolicyNet::forward);
	ClassDB::bind_method(D_METHOD("layer_count"), &DhPolicyNet::layer_count);
}

void DhPolicyNet::clear_layers() {
	layers_.clear();
}

int64_t DhPolicyNet::layer_count() const {
	return static_cast<int64_t>(layers_.size());
}

bool DhPolicyNet::add_layer(const PackedFloat64Array &w, const PackedFloat64Array &b,
		int64_t n_in, int64_t n_out, int64_t act) {
	if (n_in <= 0 || n_out <= 0) {
		return false;
	}
	if (act < ACT_LINEAR || act > ACT_LEAKY_RELU) {
		return false; // an unknown activation is a DIFFERENT net; fall back instead
	}
	if (w.size() != n_in * n_out || b.size() != n_out) {
		return false; // caller flattened it wrong; refuse rather than read past the end
	}
	Layer l;
	l.n_in = n_in;
	l.n_out = n_out;
	l.act = act;
	l.w.resize(static_cast<size_t>(n_in * n_out));
	for (int64_t i = 0; i < w.size(); ++i) {
		l.w[static_cast<size_t>(i)] = w[i];
	}
	l.b.resize(static_cast<size_t>(n_out));
	for (int64_t i = 0; i < b.size(); ++i) {
		l.b[static_cast<size_t>(i)] = b[i];
	}
	layers_.push_back(std::move(l));
	return true;
}

// Must stay the exact arithmetic twin of _forward() in game/arena/neural_policy.gd.
static inline double activate(double s, int64_t act) {
	switch (act) {
		case DhPolicyNet::ACT_TANH:
			return std::tanh(s);
		case DhPolicyNet::ACT_RELU:
			return s > 0.0 ? s : 0.0;
		case DhPolicyNet::ACT_LEAKY_RELU:
			return s > 0.0 ? s : DhPolicyNet::kLeakySlope * s;
		default:
			return s;
	}
}

PackedFloat64Array DhPolicyNet::forward(const PackedFloat64Array &x) const {
	cur_.assign(static_cast<size_t>(x.size()), 0.0);
	for (int64_t i = 0; i < x.size(); ++i) {
		cur_[static_cast<size_t>(i)] = x[i];
	}
	for (const Layer &l : layers_) {
		nxt_.assign(static_cast<size_t>(l.n_out), 0.0);
		// The GDScript original clamped the inner loop to the shorter of the
		// weight row and the running vector; keep that, so a mismatched input
		// behaves identically instead of reading garbage.
		const int64_t lim = std::min<int64_t>(l.n_in, static_cast<int64_t>(cur_.size()));
		for (int64_t o = 0; o < l.n_out; ++o) {
			const int64_t base = o * l.n_in;
			double s = l.b[static_cast<size_t>(o)];
			for (int64_t j = 0; j < lim; ++j) {
				s += l.w[static_cast<size_t>(base + j)] * cur_[static_cast<size_t>(j)];
			}
			nxt_[static_cast<size_t>(o)] = activate(s, l.act);
		}
		cur_.swap(nxt_);
	}
	PackedFloat64Array out;
	out.resize(static_cast<int64_t>(cur_.size()));
	for (size_t i = 0; i < cur_.size(); ++i) {
		out[static_cast<int64_t>(i)] = cur_[i];
	}
	return out;
}

} // namespace dh
