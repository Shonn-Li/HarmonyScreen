#include "../HarmonyClient/entry/src/main/cpp/frame_rate.h"
#include <cassert>
#include <cmath>

int main() {
    using Rate = harmony::FrameRate;
    using namespace std::chrono;
    const auto start = Rate::Time{};
    Rate rate;
    rate.reset(start);
    assert(rate.fps(start + seconds(2)) == 0);
    // A steady 30 FPS stream, including its partial first measurement window.
    rate.reset(start);
    for (int i = 1; i <= 30; ++i) {
        rate.record(start + microseconds(i * 1000000 / 30));
        if (i == 15) assert(std::abs(rate.fps(start + milliseconds(500)) - 30) < 0.01);
    }
    assert(std::abs(rate.fps(start + seconds(1)) - 30) < 0.01);
    // A stall must age out old frames even with no record() callbacks.
    assert(rate.fps(start + milliseconds(1500)) == 15);
    assert(rate.fps(start + seconds(2)) == 0);
    // Reconnection resets the measurement instead of leaking the prior rate.
    rate.reset(start + seconds(3));
    assert(rate.fps(start + milliseconds(3500)) == 0);
    rate.record(start + milliseconds(3500));
    assert(rate.fps(start + seconds(4)) == 1);
}
