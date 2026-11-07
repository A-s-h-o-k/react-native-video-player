//
//  IPlayerStateObserver.hpp
//  Player
//
//  Observer interface implemented by UI controls, OS services, and telemetry modules.
//

#ifndef IPlayerStateObserver_hpp
#define IPlayerStateObserver_hpp

#include "PlayerTypes.hpp"
#include <string>

namespace PlayerCore {

class IPlayerStateObserver {
public:
    virtual ~IPlayerStateObserver() = default;

    virtual void onStateChanged(PlaybackState newState, PlaybackState oldState) = 0;
    virtual void onTimeUpdated(double currentTime, double duration) = 0;
    virtual void onBufferUpdated(double bufferedTime, double percentage) = 0;
    virtual void onMuteChanged(bool isMuted, float volume) = 0;
    virtual void onPlaybackRateChanged(float rate) = 0;
    virtual void onNetworkMetricsUpdated(double pingMs, double bandwidthBitrateBps) {}
    virtual void onError(int errorCode, const std::string& message) = 0;
};

} // namespace PlayerCore

#endif /* IPlayerStateObserver_hpp */
