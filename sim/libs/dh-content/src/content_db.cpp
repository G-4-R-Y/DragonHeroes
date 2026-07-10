#include <dh/content/content_db.hpp>

namespace dh::content {

ContentHandle ContentDb::intern(std::string_view id) {
    if (const auto it = by_name_.find(std::string(id)); it != by_name_.end()) {
        return it->second;
    }
    const auto handle = static_cast<ContentHandle>(names_.size());
    names_.emplace_back(id);
    by_name_.emplace(names_.back(), handle);
    return handle;
}

ContentHandle ContentDb::find(std::string_view id) const {
    const auto it = by_name_.find(std::string(id));
    return it == by_name_.end() ? kInvalidHandle : it->second;
}

std::string_view ContentDb::name_of(ContentHandle handle) const {
    return handle < names_.size() ? std::string_view(names_[handle]) : std::string_view();
}

} // namespace dh::content
