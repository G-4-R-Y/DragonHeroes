#pragma once
#include <cstdint>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

// dh-content (docs/tech/23): the only path content data enters the sim. Loads the
// validated definitions from content/ and interns stable string IDs
// ("core.item.emberfang_blade") into dense u32 handles used everywhere hot.
// M0 scope: the interner + typed-table skeleton. The pack loader lands with the
// first real content schema consumers in M1.
namespace dh::content {

using ContentHandle = std::uint32_t;
inline constexpr ContentHandle kInvalidHandle = 0xffffffffu;

class ContentDb {
public:
    // Interns `id`, returning its dense handle (stable for the lifetime of the db).
    ContentHandle intern(std::string_view id);

    // Returns the handle for `id` or kInvalidHandle if never interned.
    ContentHandle find(std::string_view id) const;

    std::string_view name_of(ContentHandle handle) const;
    std::uint32_t size() const { return static_cast<std::uint32_t>(names_.size()); }

private:
    std::unordered_map<std::string, ContentHandle> by_name_;
    std::vector<std::string> names_;
};

} // namespace dh::content
