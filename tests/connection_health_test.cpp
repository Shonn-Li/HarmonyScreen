#include "../HarmonyClient/entry/src/main/cpp/connection_health.h"
#include <cassert>
#include <functional>

bool fails(const std::function<void()>& f) {
    try { f(); return false; } catch (const std::runtime_error&) { return true; }
}
int main() {
    harmony::ConnectionHealth health;
    health.start(100);
    assert(!health.pingDue(101.9));
    assert(health.pingDue(102));
    health.sentPing(102);
    assert(!health.pingDue(103));
    health.check(107.9,true);
    // Open-but-dead tunnel must time out even after previously showing video.
    assert(fails([&] { health.check(108,true); }));
    // A static desktop stays connected through heartbeat replies.
    for (int i=102; i<180; i+=2) { health.received(i); health.check(i,true); }
    // Pong-only connections cannot pretend that the screen is working.
    health.start(200);
    for (int i=202; i<212; i+=2) { health.received(i); health.check(i,false); }
    health.received(212);
    assert(fails([&] { health.check(212,false); }));
    health.start(300); // Reconnect resets deadlines.
    health.check(301,false);
}
