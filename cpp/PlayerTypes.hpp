//
//  PlayerTypes.hpp
//  Player
//
//  Cross-platform playback state types and snapshot structures.
//

#ifndef PlayerTypes_hpp
#define PlayerTypes_hpp

#include <string>

namespace PlayerCore {

enum class PlaybackState {
    Idle,       // Initialized / Reset, no media loaded
    Loading,    // Media manifest / metadata loading
    Ready,      // Media metadata loaded, duration known, ready to play
    Playing,    // Active playback, clock running, frames rendering
    Paused,     // Playback paused at current timestamp
    Buffering,  // Clock paused waiting for network buffer
    Ended,      // Playback reached end of media
    Error       // Playback error occurred
};

struct PlayerSnapshot {
    PlaybackState state = PlaybackState::Idle;
    double currentTime = 0.0;
    double duration = 0.0;
    double bufferedTime = 0.0;
    float playbackRate = 1.0f;
    float volume = 1.0f;
    bool isMuted = false;
    bool isScrubbing = false;
    int errorCode = 0;
    std::string errorMessage = "";
};

inline const char* PlaybackStateToString(PlaybackState state) {
    switch (state) {
        case PlaybackState::Idle: return "Idle";
        case PlaybackState::Loading: return "Loading";
        case PlaybackState::Ready: return "Ready";
        case PlaybackState::Playing: return "Playing";
        case PlaybackState::Paused: return "Paused";
        case PlaybackState::Buffering: return "Buffering";
        case PlaybackState::Ended: return "Ended";
        case PlaybackState::Error: return "Error";
    }
}

} // namespace PlayerCore

#endif /* PlayerTypes_hpp */
