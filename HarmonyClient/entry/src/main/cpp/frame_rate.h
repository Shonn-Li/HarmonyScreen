// Copyright 2026 Shonn Li. MIT license.
#pragma once
#include <algorithm>
#include <chrono>
#include <deque>
#include <mutex>

namespace harmony {
// Counts successful decoder submissions to the display surface, not panel refreshes.
// Keep a rolling second so a frozen stream falls to zero even without new frames.
class FrameRate {
public:
    using Clock = std::chrono::steady_clock;
    using Time = Clock::time_point;
    void reset(Time now = Clock::now()) {
        std::lock_guard<std::mutex> lock(mutex_);
        started_ = now;
        frames_.clear();
    }
    void record(Time now = Clock::now()) {
        std::lock_guard<std::mutex> lock(mutex_);
        prune(now);
        frames_.push_back(now);
    }
    double fps(Time now = Clock::now()) {
        std::lock_guard<std::mutex> lock(mutex_);
        prune(now);
        const double seconds = std::min(1.0, std::chrono::duration<double>(now - started_).count());
        return seconds >= 0.25 ? frames_.size() / seconds : 0.0;
    }
private:
    void prune(Time now) {
        const auto oldest = now - std::chrono::seconds(1);
        while (!frames_.empty() && frames_.front() <= oldest) frames_.pop_front();
    }
    std::mutex mutex_;
    Time started_ = Clock::now();
    std::deque<Time> frames_;
};
}
