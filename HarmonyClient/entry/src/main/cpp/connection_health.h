#pragma once
#include <stdexcept>

namespace harmony {
// Monotonic seconds. Video may be static; a ping/pong keeps that healthy.
// A local HDC socket that survives a broken USB link must not wait forever.
class ConnectionHealth {
    double started_ = 0, lastReceived_ = 0, lastPing_ = 0;
public:
    void start(double now) { started_ = lastReceived_ = lastPing_ = now; }
    void received(double now) { lastReceived_ = now; }
    bool pingDue(double now) const { return now - lastPing_ >= 2; }
    void sentPing(double now) { lastPing_ = now; }
    void check(double now, bool hasFrame) const {
        if (now - lastReceived_ >= 8)
            throw std::runtime_error("Mac stopped responding. Reconnecting automatically.");
        if (!hasFrame && now - started_ >= 12)
            throw std::runtime_error("No picture from Mac. Check Screen Recording permission on the Mac.");
    }
};
}
