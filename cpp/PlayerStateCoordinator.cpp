//
//  PlayerStateCoordinator.cpp
//  Player
//
//  Cross-platform thread-safe headless player state machine and event coordinator.
//

#include "PlayerStateCoordinator.hpp"
#include <cmath>

namespace PlayerCore {

PlayerStateCoordinator::PlayerStateCoordinator() {
    snapshot_.state = PlaybackState::Idle;
    snapshot_.currentTime = 0.0;
    snapshot_.duration = 0.0;
    snapshot_.bufferedTime = 0.0;
    snapshot_.playbackRate = 1.0f;
    snapshot_.volume = 1.0f;
    snapshot_.isMuted = false;
    snapshot_.isScrubbing = false;
}

PlayerStateCoordinator::~PlayerStateCoordinator() {
    std::lock_guard<std::mutex> lock(stateMutex_);
    observers_.clear();
    bridge_ = nullptr;
}

void PlayerStateCoordinator::setEngineBridge(IPlaybackEngineBridge* bridge) {
    std::lock_guard<std::mutex> lock(stateMutex_);
    bridge_ = bridge;
}

void PlayerStateCoordinator::addObserver(const std::shared_ptr<IPlayerStateObserver>& observer) {
    if (!observer) return;
    std::lock_guard<std::mutex> lock(stateMutex_);
    for (const auto& w : observers_) {
        if (auto s = w.lock()) {
            if (s.get() == observer.get()) {
                return; // Already registered
            }
        }
    }
    observers_.push_back(observer);
    // Send initial state snapshot to new observer
    observer->onStateChanged(snapshot_.state, PlaybackState::Idle);
    observer->onTimeUpdated(snapshot_.currentTime, snapshot_.duration);
}

void PlayerStateCoordinator::removeObserver(const std::shared_ptr<IPlayerStateObserver>& observer) {
    if (!observer) return;
    removeObserver(observer.get());
}

void PlayerStateCoordinator::removeObserver(IPlayerStateObserver* observer) {
    if (!observer) return;
    std::lock_guard<std::mutex> lock(stateMutex_);
    for (auto it = observers_.begin(); it != observers_.end(); ) {
        if (auto s = it->lock()) {
            if (s.get() == observer) {
                it = observers_.erase(it);
                return;
            } else {
                ++it;
            }
        } else {
            it = observers_.erase(it);
        }
    }
}

std::vector<std::shared_ptr<IPlayerStateObserver>> PlayerStateCoordinator::getActiveObserversLocked() {
    std::vector<std::shared_ptr<IPlayerStateObserver>> active;
    for (auto it = observers_.begin(); it != observers_.end(); ) {
        if (auto s = it->lock()) {
            active.push_back(s);
            ++it;
        } else {
            it = observers_.erase(it);
        }
    }
    return active;
}

PlayerSnapshot PlayerStateCoordinator::getSnapshot() const {
    std::lock_guard<std::mutex> lock(stateMutex_);
    return snapshot_;
}


#pragma mark - Inbound User Requests

void PlayerStateCoordinator::requestPlay() {
    IPlaybackEngineBridge* b = nullptr;
    bool isEnded = false;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        isEnded = (snapshot_.state == PlaybackState::Ended);
        b = bridge_;
    }
    if (b) {
        if (isEnded) {
            b->executeSeek(0.0);
        }
        b->executePlay();
    }
}

void PlayerStateCoordinator::requestPause() {
    IPlaybackEngineBridge* b = nullptr;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        b = bridge_;
    }
    if (b) {
        b->executePause();
    }
}

void PlayerStateCoordinator::requestTogglePlayPause() {
    bool isPlaying = false;
    bool isEnded = false;
    IPlaybackEngineBridge* b = nullptr;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        isPlaying = (snapshot_.state == PlaybackState::Playing);
        isEnded = (snapshot_.state == PlaybackState::Ended);
        b = bridge_;
    }
    if (b) {
        if (isPlaying) {
            b->executePause();
        } else if (isEnded) {
            b->executeSeek(0.0);
            b->executePlay();
        } else {
            b->executePlay();
        }
    }
}

void PlayerStateCoordinator::requestSeek(double seconds) {
    IPlaybackEngineBridge* b = nullptr;
    double clamped = 0.0;
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    PlaybackState oldState = PlaybackState::Idle;
    bool stateChanged = false;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        double dur = snapshot_.duration;
        clamped = std::max(0.0, seconds);
        if (dur > 0.0 && !std::isnan(dur)) {
            clamped = std::min(clamped, dur);
        }
        snapshot_.currentTime = clamped;
        if (snapshot_.state == PlaybackState::Ended && clamped < dur) {
            oldState = snapshot_.state;
            snapshot_.state = PlaybackState::Paused;
            stateChanged = true;
            observersCopy = getActiveObserversLocked();
        }
        b = bridge_;
    }
    if (stateChanged) {
        for (const auto& obs : observersCopy) {
            obs->onStateChanged(PlaybackState::Paused, oldState);
        }
    }
    if (b) {
        b->executeSeek(clamped);
    }
}

void PlayerStateCoordinator::requestStepSeek(double deltaSeconds) {
    double target = 0.0;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        target = snapshot_.currentTime + deltaSeconds;
    }
    requestSeek(target);
}

#pragma mark - 3-Phase Scrubbing Lifecycle

void PlayerStateCoordinator::startScrubbing() {
    std::lock_guard<std::mutex> lock(stateMutex_);
    wasPlayingBeforeScrub_ = (snapshot_.state == PlaybackState::Playing);
    snapshot_.isScrubbing = true;
}

void PlayerStateCoordinator::scrubTo(double seconds) {
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    double clamped = 0.0;
    double dur = 0.0;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        dur = snapshot_.duration;
        clamped = std::max(0.0, seconds);
        if (dur > 0.0 && !std::isnan(dur)) {
            clamped = std::min(clamped, dur);
        }
        snapshot_.currentTime = clamped;
        observersCopy = getActiveObserversLocked();
    }
    // Update UI scrub thumb smoothly without sending seeks to the decoder
    for (const auto& obs : observersCopy) {
        obs->onTimeUpdated(clamped, dur);
    }
}


void PlayerStateCoordinator::endScrubbing(double finalSeconds) {
    IPlaybackEngineBridge* b = nullptr;
    bool shouldResume = false;
    double clamped = 0.0;
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    PlaybackState oldState = PlaybackState::Idle;
    bool stateChanged = false;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        snapshot_.isScrubbing = false;
        double dur = snapshot_.duration;
        clamped = std::max(0.0, finalSeconds);
        if (dur > 0.0 && !std::isnan(dur)) {
            clamped = std::min(clamped, dur);
        }
        snapshot_.currentTime = clamped;
        shouldResume = wasPlayingBeforeScrub_;
        if (snapshot_.state == PlaybackState::Ended && clamped < dur) {
            oldState = snapshot_.state;
            snapshot_.state = PlaybackState::Paused;
            stateChanged = true;
            observersCopy = getActiveObserversLocked();
        }
        b = bridge_;
    }
    if (stateChanged) {
        for (const auto& obs : observersCopy) {
            obs->onStateChanged(PlaybackState::Paused, oldState);
        }
    }
    if (b) {
        b->executeSeek(clamped);
        if (shouldResume) {
            b->executePlay();
        }
    }
}

void PlayerStateCoordinator::requestPlaybackRate(float rate) {
    IPlaybackEngineBridge* b = nullptr;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        snapshot_.playbackRate = rate;
        b = bridge_;
    }
    if (b) {
        b->executePlaybackRate(rate);
    }
}

void PlayerStateCoordinator::requestVolume(float volume) {
    IPlaybackEngineBridge* b = nullptr;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        snapshot_.volume = std::max(0.0f, std::min(1.0f, volume));
        b = bridge_;
    }
    if (b) {
        b->executeVolume(snapshot_.volume);
    }
}

void PlayerStateCoordinator::requestMute(bool muted) {
    IPlaybackEngineBridge* b = nullptr;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        snapshot_.isMuted = muted;
        b = bridge_;
    }
    if (b) {
        b->executeMute(muted);
    }
}

void PlayerStateCoordinator::requestReset() {
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    PlaybackState oldState = PlaybackState::Idle;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        oldState = snapshot_.state;
        snapshot_.state = PlaybackState::Idle;
        snapshot_.currentTime = 0.0;
        snapshot_.duration = 0.0;
        snapshot_.bufferedTime = 0.0;
        snapshot_.isScrubbing = false;
        observersCopy = getActiveObserversLocked();
    }
    for (const auto& obs : observersCopy) {
        obs->onStateChanged(PlaybackState::Idle, oldState);
        obs->onTimeUpdated(0.0, 0.0);
    }
}

#pragma mark - Inbound Engine Notifications

void PlayerStateCoordinator::notifyEngineState(PlaybackState state) {
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    PlaybackState oldState = PlaybackState::Idle;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        if (snapshot_.state == state) {
            return;
        }
        // Protect Ended state: do not allow engine Paused to overwrite Ended
        if (state == PlaybackState::Paused && snapshot_.state == PlaybackState::Ended) {
            return;
        }
        oldState = snapshot_.state;
        snapshot_.state = state;
        observersCopy = getActiveObserversLocked();
    }
    for (const auto& obs : observersCopy) {
        obs->onStateChanged(state, oldState);
    }
}

void PlayerStateCoordinator::notifyEngineTime(double currentTime) {
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    double duration = 0.0;
    PlaybackState oldState = PlaybackState::Idle;
    bool transitionedToEnded = false;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        // If user is actively dragging the scrubber, ignore engine time updates to prevent jitter
        if (snapshot_.isScrubbing) {
            return;
        }
        snapshot_.currentTime = currentTime;
        duration = snapshot_.duration;

        // Auto-detect ended state when media clock reaches or passes the duration threshold
        if (duration > 0.0 && !std::isnan(duration) && currentTime >= (duration - 0.35) &&
            snapshot_.state != PlaybackState::Ended && snapshot_.state != PlaybackState::Idle && snapshot_.state != PlaybackState::Loading) {
            oldState = snapshot_.state;
            snapshot_.state = PlaybackState::Ended;
            transitionedToEnded = true;
        }
        observersCopy = getActiveObserversLocked();
    }
    if (transitionedToEnded) {
        for (const auto& obs : observersCopy) {
            obs->onStateChanged(PlaybackState::Ended, oldState);
        }
    }
    for (const auto& obs : observersCopy) {
        obs->onTimeUpdated(currentTime, duration);
    }
}

void PlayerStateCoordinator::notifyEngineDuration(double duration) {
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    double currentTime = 0.0;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        snapshot_.duration = duration;
        currentTime = snapshot_.currentTime;
        observersCopy = getActiveObserversLocked();
    }
    for (const auto& obs : observersCopy) {
        obs->onTimeUpdated(currentTime, duration);
    }
}

void PlayerStateCoordinator::notifyEngineBuffer(double bufferedTime) {
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    double percentage = 0.0;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        snapshot_.bufferedTime = bufferedTime;
        if (snapshot_.duration > 0.0) {
            percentage = std::min(100.0, (bufferedTime / snapshot_.duration) * 100.0);
        }
        observersCopy = getActiveObserversLocked();
    }
    for (const auto& obs : observersCopy) {
        obs->onBufferUpdated(bufferedTime, percentage);
    }
}

void PlayerStateCoordinator::notifyEngineError(int errorCode, const std::string& message) {
    std::vector<std::shared_ptr<IPlayerStateObserver>> observersCopy;
    PlaybackState oldState = PlaybackState::Idle;
    {
        std::lock_guard<std::mutex> lock(stateMutex_);
        oldState = snapshot_.state;
        snapshot_.state = PlaybackState::Error;
        snapshot_.errorCode = errorCode;
        snapshot_.errorMessage = message;
        observersCopy = getActiveObserversLocked();
    }
    for (const auto& obs : observersCopy) {
        obs->onStateChanged(PlaybackState::Error, oldState);
        obs->onError(errorCode, message);
    }
}

} // namespace PlayerCore

