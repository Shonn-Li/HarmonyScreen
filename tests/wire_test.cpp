#include "../HarmonyClient/entry/src/main/cpp/wire.h"
#include <cassert>
#include <functional>
bool rejects(const std::function<void()>& f) { try { f(); return false; } catch (const std::runtime_error&) { return true; } }
int main() {
    uint8_t good[] = {0,0,1,0}; assert(harmony::frameLength(good)==256);
    uint8_t empty[] = {0,0,0,0}; assert(rejects([&] { harmony::frameLength(empty); }));
    uint8_t huge[] = {0x7f,0xff,0xff,0xff}; assert(rejects([&] { harmony::frameLength(huge); }));
    harmony::validateDisplay(3184,2232,0);
    assert(rejects([] { harmony::validateDisplay(0,2232,0); }));
    assert(rejects([] { harmony::validateDisplay(100000,100000,0); }));
    assert(rejects([] { harmony::validateDisplay(1920,1080,90); }));
}
