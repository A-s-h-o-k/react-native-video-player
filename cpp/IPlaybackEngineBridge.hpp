//
//  IPlaybackEngineBridge.hpp
//  Player
//
//  Pure virtual interface for triggering native player hardware operations (AVPlayer / ExoPlayer).
//

#ifndef IPlaybackEngineBridge_hpp
#define IPlaybackEngineBridge_hpp

namespace PlayerCore {

class IPlaybackEngineBridge {
public:
    virtual ~IPlaybackEngineBridge() = default;

    virtual void executePlay() = 0;
    virtual void executePause() = 0;
    virtual void executeSeek(double seconds) = 0;
    virtual void executePlaybackRate(float rate) = 0;
    virtual void executeVolume(float volume) = 0;
    virtual void executeMute(bool muted) = 0;
};

} // namespace PlayerCore

#endif /* IPlaybackEngineBridge_hpp */
