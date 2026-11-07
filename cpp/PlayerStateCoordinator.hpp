//
//  PlayerStateCoordinator.hpp
//  Player
//
//  Cross-platform thread-safe headless player state machine and event coordinator.
//

#ifndef PlayerStateCoordinator_hpp
#define PlayerStateCoordinator_hpp

#include "PlayerTypes.hpp"
#include "IPlayerStateObserver.hpp"
#include "IPlaybackEngineBridge.hpp"

#include <vector>
#include <mutex>
#include <memory>
#include <algorithm>

namespace PlayerCore {

class PlayerStateCoordinator {
public:
    PlayerStateCoordinator();
    ~PlayerStateCoordinator();

    // 1. Engine Bridge Binding
    void setEngineBridge(IPlaybackEngineBridge* bridge);

    // 2. Observer Subscriptions (Thread-Safe Weak Pointer Pattern)
    void addObserver(const std::shared_ptr<IPlayerStateObserver>& observer);
    void removeObserver(const std::shared_ptr<IPlayerStateObserver>& observer);
    void removeObserver(IPlayerStateObserver* observer);

    // 3. Thread-Safe Snapshot Query
    PlayerSnapshot getSnapshot() const;

    // 4. Inbound User / Controller Requests
    void requestPlay();
    void requestPause();
    void requestTogglePlayPause();
    void requestSeek(double seconds);
    void requestStepSeek(double deltaSeconds);

    // 3-Phase Scrubbing Lifecycle
    void startScrubbing();
    void scrubTo(double seconds);
    void endScrubbing(double finalSeconds);

    void requestPlaybackRate(float rate);
    void requestVolume(float volume);
    void requestMute(bool muted);
    void requestReset();

    // 5. Inbound Engine Notifications (From AVPlayer / ExoPlayer)
    void notifyEngineState(PlaybackState state);
    void notifyEngineTime(double currentTime);
    void notifyEngineDuration(double duration);
    void notifyEngineBuffer(double bufferedTime);
    void notifyEngineNetworkMetrics(double pingMs, double bandwidthBitrateBps);
    void notifyEngineError(int errorCode, const std::string& message);

private:
    mutable std::mutex stateMutex_;
    PlayerSnapshot snapshot_;
    IPlaybackEngineBridge* bridge_ = nullptr;
    std::vector<std::weak_ptr<IPlayerStateObserver>> observers_;
    bool wasPlayingBeforeScrub_ = false;

    std::vector<std::shared_ptr<IPlayerStateObserver>> getActiveObserversLocked();
    void updateStateInternal(PlaybackState newState);
};


} // namespace PlayerCore

#endif /* PlayerStateCoordinator_hpp */
