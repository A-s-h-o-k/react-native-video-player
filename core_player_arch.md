# Headless Core Player Architecture Specification (`core_player_arch.md`)

## 1. Overview & The Separation Principle

The **Headless Core Player** is the central playback engine of the architecture. It is strictly **decoupled from all UI elements**.

### Core Tenet: Zero UI in the Core Engine
- The Core Player has **no views, no buttons, no sliders, no colors, and no layout logic**.
- Its sole purpose is to manage **media loading, playback state transitions, timing calculation, buffering, audio/subtitles tracks, and platform engine adaptation**.
- Any UI (such as [base_layout_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/base_layout_arch.md), lock-screen media widgets, or Apple TV focus layers) acts as an external **observer** that subscribes to state and sends commands.

---

## 2. High-Level Core Architecture Diagram

```mermaid
graph TD
    subgraph Inbound_Callers ["Inbound Command Callers (No Direct Engine Coupling)"]
        UI_Controls["Native ControlLayer / Custom UIs"]
        Media_Session["OS MediaSession (Lock Screen / Siri / Assistant)"]
        RN_Bridge["React Native Fabric Ref Commands (ref.current.play())"]
    end

    subgraph Headless_Core ["Headless Core Player (Cross-Platform)"]
        Command_API["Core Commands API (load, play, pause, seek, setRate)"]
        State_Machine["Deterministic State Machine (Idle, Ready, Playing, Buffering...)"]
        Scrub_Engine["High-Precision Scrubbing & Time Clamping Engine"]
        Observer_Bus["Observer Event Bus (IPlayerObserver Registry)"]
    end

    subgraph Platform_Adapters ["Platform Native Engine Adapters"]
        iOS_Adapter["iOS AVPlayerAdapter (Objective-C++ / AVFoundation)"]
        Android_Adapter["Android ExoPlayerAdapter (Kotlin / Media3)"]
    end

    subgraph Outbound_Observers ["Outbound Event Observers"]
        Obs_UI["ControlLayer (Updates Buttons, Sliders, Spinners)"]
        Obs_Media["MPNowPlayingInfoCenter / MediaSessionCompat"]
        Obs_Telemetry["React Native Telemetry (onProgress, onStateChange)"]
        Obs_A11y["Accessibility Announcements (VoiceOver / TalkBack)"]
    end

    %% Wiring
    UI_Controls -->|Commands| Command_API
    Media_Session -->|Commands| Command_API
    RN_Bridge -->|Commands| Command_API

    Command_API --> State_Machine
    Command_API --> Scrub_Engine
    State_Machine <--> Platform_Adapters
    Scrub_Engine <--> Platform_Adapters

    Platform_Adapters -->|Engine Events: KVO / Player.Listener| State_Machine
    State_Machine --> Observer_Bus
    Scrub_Engine --> Observer_Bus

    Observer_Bus -->|onStateChanged| Obs_UI
    Observer_Bus -->|onTimeUpdated| Obs_UI
    Observer_Bus -->|onStateChanged / onTimeUpdated| Obs_Media
    Observer_Bus -->|Throttled onProgress| Obs_Telemetry
    Observer_Bus -->|Live State Events| Obs_A11y
```

---

## 3. Formal Playback State Machine

The core enforces a strict, deterministic state machine. No UI can force an invalid transition.

```mermaid
stateDiagram-v2
    [*] --> IDLE : Initialize / Release

    IDLE --> LOADING : load(source)
    LOADING --> READY : First Frame Decoded & Duration Known
    LOADING --> ERROR : Network Failure / Invalid URL / DRM Error

    READY --> PLAYING : play()
    PLAYING --> PAUSED : pause()
    PAUSED --> PLAYING : play()

    PLAYING --> BUFFERING : Network Stalled / Buffer Underflow
    BUFFERING --> PLAYING : Sufficient Buffer Recharged

    PLAYING --> ENDED : Playback Reached Duration
    ENDED --> PLAYING : seekTo(0) & play()

    READY --> IDLE : reset() / release()
    PAUSED --> IDLE : reset() / release()
    ERROR --> IDLE : retry() / reset()
```

### State Definitions:
- **`IDLE`**: Player instance exists, but no media source is loaded. Decoders are idle.
- **`LOADING`**: Media item requested; manifest / headers / initial buffer loading.
- **`READY`**: Video metadata (duration, width, height, audio/subtitle tracks) is parsed; ready for immediate playback.
- **`PLAYING`**: Audio/video clock is running and frames are rendering.
- **`PAUSED`**: Audio/video clock is paused at the current timestamp.
- **`BUFFERING`**: Media is temporarily paused while waiting for network data.
- **`ENDED`**: Current timestamp reached the video duration.
- **`ERROR`**: Playback failed (network disconnect, decoding failure, DRM license expiration).

---

## 4. Inbound Command API (Platform-Agnostic Interface)

Every platform adapter and shared core component implements this uniform command interface:

```cpp
class ICorePlayer {
public:
    virtual ~ICorePlayer() = default;

    // Lifecycle & Loading
    virtual void load(const std::string& url, const std::string& mimeType = "") = 0;
    virtual void reset() = 0;
    virtual void release() = 0;

    // Playback Controls
    virtual void play() = 0;
    virtual void pause() = 0;
    virtual void togglePlayPause() = 0;
    virtual void stop() = 0;

    // Seeking & Scrubbing
    virtual void seekTo(double seconds, bool accurate = true) = 0;
    virtual void seekBy(double deltaSeconds) = 0; // e.g. +15s, -15s
    virtual void startScrubbing() = 0;
    virtual void scrubTo(double seconds) = 0;
    virtual void endScrubbing(double finalSeconds) = 0;

    // Audio & Rate
    virtual void setPlaybackRate(float rate) = 0; // 0.5x, 1.0x, 1.5x, 2.0x
    virtual void setVolume(float volume) = 0;     // 0.0f to 1.0f
    virtual void setMuted(bool muted) = 0;

    // Track Selection
    virtual void selectAudioTrack(int trackIndex) = 0;
    virtual void selectTextTrack(int trackIndex) = 0;
};
```

---

## 5. Outbound Observer Interface (`IPlayerObserver`)

UI controls, OS media notification services, and analytics modules subscribe to the core via this observer contract:

```cpp
class IPlayerObserver {
public:
    virtual ~IPlayerObserver() = default;

    // Playback State
    virtual void onPlaybackStateChanged(PlaybackState newState) = 0;
    
    // Time & Progress (Dispatched on Audio/Video Clock)
    virtual void onTimeUpdated(double currentTime, double duration) = 0;
    virtual void onBufferProgress(double bufferedSeconds, double percentage) = 0;
    
    // Media Dimensions & Metadata
    virtual void onVideoDimensionsChanged(int width, int height) = 0;
    virtual void onDurationChanged(double duration) = 0;
    
    // Track Changes
    virtual void onTracksAvailable(const std::vector<AudioTrack>& audioTracks, 
                                   const std::vector<TextTrack>& textTracks) = 0;
    
    // Error Reporting
    virtual void onPlaybackError(int errorCode, const std::string& message) = 0;
};
```

---

## 6. Platform Engine Binding (Bridging the Real Engines)

### iOS / tvOS (`AVPlayerAdapter`)
- Wraps an `AVPlayer` and `AVPlayerItem`.
- **State Listening**: Uses Key-Value Observing (KVO) on `player.timeControlStatus` (`paused`, `waitingToPlayAtSpecifiedRate`, `playing`).
- **Timing**: Adds an `addPeriodicTimeObserverForInterval:queue:usingBlock:` on the main dispatch queue (e.g. interval of `CMTimeMake(1, 4)` = 4 updates per second).
- **Duration**: Observes `currentItem.duration` via KVO on `AVPlayerItemStatusReadyToPlay`.
- **End Notification**: Subscribes to `AVPlayerItemDidPlayToEndTimeNotification`.

### Android / Android TV (`ExoPlayerAdapter`)
- Wraps an `androidx.media3.exoplayer.ExoPlayer`.
- **State Listening**: Uses `Player.Listener`:
  - `onPlaybackStateChanged(state)`: Maps `STATE_IDLE`, `STATE_BUFFERING`, `STATE_READY`, `STATE_ENDED`.
  - `onIsPlayingChanged(isPlaying)`: Dispatches `PLAYING` or `PAUSED`.
  - `onVideoSizeChanged(videoSize)`: Dispatches dimensions.
- **Timing**: Runs a lightweight periodic `Runnable` on the Android Main Looper during `PLAYING` states.

---

## 7. Thread Safety & Lifecycle Management

1. **Main Thread UI Safety**: All observer events delivered to UI controls are guaranteed to dispatch on the platform's **Main / UI Thread** (UIKit / Android Main Looper) so UI views never crash from background thread updates.
2. **Deterministic Teardown (`release()`)**:
   - iOS: Removes all periodic time observers and KVO observers before releasing `AVPlayer` memory.
   - Android: Calls `exoPlayer.stop()` and `exoPlayer.release()` to instantly reclaim hardware decoder resources.
3. **Background Audio & PiP Continuity**:
   - Because the core is headless, detaching or minimizing the video surface does **not stop audio playback**. 
   - When entering Picture-in-Picture, only the video surface transfers to the PiP window; the core state machine continues running uninterrupted.

---

## 8. Implementation & Verification Status

- [x] **Shared C++ Coordinator Core (`cpp/`)**: Fully implemented in [PlayerStateCoordinator.cpp](file:///Users/ashokammineni/video-player/new_2/Player/cpp/PlayerStateCoordinator.cpp), thread-safe with `std::mutex`, zero UI dependencies.
- [x] **iOS AVPlayer Adapter (`AVPlayerAdapter.mm`)**: Fully implemented, registered in `project.pbxproj`, and verified with `xcodebuild` (Exit code 0).
- [x] **Android Media3 ExoPlayer Adapter (`BasePlayer.kt`)**: Fully implemented base ExoPlayer wrapper with `onPlaybackStateListener` callbacks dispatched to `ControlLayer.kt` and `ReactVideoPlayer.kt`.

