#pragma once
#include <cstdint>
#include <stdexcept>
#include <vector>
namespace harmony {
constexpr uint32_t MaxFrame = 16 * 1024 * 1024;
inline uint32_t be32(const uint8_t* p) {
    return uint32_t(p[0]) << 24 | uint32_t(p[1]) << 16 | uint32_t(p[2]) << 8 | p[3];
}
inline uint32_t frameLength(const uint8_t* p) {
    auto n = be32(p);
    if (!n || n > MaxFrame) throw std::runtime_error("Invalid video frame size");
    return n;
}
inline void validateDisplay(uint32_t w, uint32_t h, uint32_t transform) {
    if (!w || !h || w > 8192 || h > 8192 || uint64_t(w)*h > 33554432)
        throw std::runtime_error("Display exceeds supported dimensions");
    if (transform != 0) throw std::runtime_error("Set rotation and flip to zero in the Mac app for this preview");
}
}
