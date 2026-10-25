# Quick Reference & Documentation Map (`quick-ref.md`)

## 1. Documentation Sitemap

This repository maintains living architectural documentation. Every document has a distinct scope and purpose:

| Document | Purpose & Scope | Key Topics Covered |
| :--- | :--- | :--- |
| [TASK_STATUS.md](file:///Users/ashokammineni/video-player/new_2/Player/TASK_STATUS.md) | **Live Implementation Tracker** | • Active task spotlight & currently running work<br>• Full component milestone status matrix<br>• Mandatory agent update workflow & protocol |
| [AGENTS.md](file:///Users/ashokammineni/video-player/new_2/Player/AGENTS.md) | **Governance & Rules** | • Strict User Approval Policy (Permission required before mutating code)<br>• 11 Core Architectural & Engineering Principles<br>• Living documentation and task tracking mandate |
| [ARCHITECTURE.md](file:///Users/ashokammineni/video-player/new_2/Player/ARCHITECTURE.md) | **Master System Architecture** | • High-level system architecture & Mermaid diagrams<br>• Dual-lane data & event flow (High-frequency native vs Low-frequency JS)<br>• Pre-built native templates & configuration props<br>• Layer-by-layer technical breakdown<br>• Enterprise features (TV, A11y, Voice, Audio Focus, PiP)<br>• System-wide implementation status |
| [USAGE_GUIDE.md](file:///Users/ashokammineni/video-player/new_2/Player/USAGE_GUIDE.md) | **React Native Usage & API Reference** | • Props reference table (`videoUrl`, `title`, `play`, `seekTo`, etc.)<br>• Event callbacks (`onScriptLoaded`, `onError`, `onPlay`, etc.)<br>• Practical code recipes (16:9 aspect ratio, controlled buttons, playlists)<br>• TypeScript interfaces (`VideoPlayerProps`) |
| [network_auth_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/network_auth_arch.md) | **Networking, Auth & Hardware DRM** | • Custom HTTP headers injection (`AVURLAssetHTTPHeaderFieldsKey` & `DefaultHttpDataSource`)<br>• Apple FairPlay Streaming (`AVContentKeySession`, SPC <-> CKC)<br>• Google Widevine Modular (`DefaultDrmSessionManager` L1/L3)<br>• Native interceptors & thread-safe token refresh<br>• Unified error propagation into C++ coordinator |
| [core_player_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/core_player_arch.md) | **Headless Core Player** | • Zero-UI separation principle<br>• Formal 8-state deterministic playback state machine<br>• Inbound Commands API (`ICorePlayer`) & Outbound Observer Bus (`IPlayerObserver`)<br>• Platform engine adapters (`AVPlayerAdapter` & `ExoPlayerAdapter`) |
| [state_manager_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/state_manager_arch.md) | **Headless State Coordinator** | • Pure C++17 thread-safe state machine & scrub math (`PlayerStateCoordinator`)<br>• Memory safety: `std::weak_ptr` observer pattern with auto-pruning<br>• Outbound Engine Bridge (`IPlaybackEngineBridge`) & Observer Bus (`IPlayerStateObserver`)<br>• Cross-platform `cpp/` directory structure |
| [base_layout_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/base_layout_arch.md) | **Master Overlay Container** | • `BaseControlLayer` / `ControlLayer` specification<br>• Full-bleed z-index layering over native video surface<br>• Smart auto-hide lifecycle (5s countdown, pause immunity, scrub immunity)<br>• State fan-out from engine to child sections |
| [sections_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/sections_arch.md) | **Section Layouts & Delegates** | • 3-Section breakdown: `TopSection`, `CenterSection`, `BottomSection`<br>• Decoupled communication protocols (`CenterSectionDelegate`, `TopSectionDelegate`, `BottomSectionDelegate`)<br>• Apple TV & Android TV 2D remote focus navigation grid |
| [button_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/button_arch.md) | **Base Button Primitive** | • `CommonButton` foundation (iOS & Android)<br>• Sizing presets (Small, Medium, Large)<br>• Apple HIG 44×44pt & Material 48×48dp minimum touch targets<br>• Spring micro-interactions & Material ripple<br>• tvOS & Android TV focus engine scaling (1.15x)<br>• VoiceOver & TalkBack accessibility |
| [quick-ref.md](file:///Users/ashokammineni/video-player/new_2/Player/quick-ref.md) | **Index & Update Guide** | • This document: fast lookup index, code mapping, and update triggers |

---

## 2. "When to Update What" (Update Guide for Developers & Agents)

Whenever a change is made in the codebase, use this matrix to identify which documentation files must be updated:

```mermaid
graph TD
    Change[Code or Design Change] --> CheckType{What Changed?}

    CheckType -->|Task Started or Completed| UpdateTaskStatus["Update TASK_STATUS.md (Spotlight & Matrix)"]
    CheckType -->|Button styling, sizing, touch targets, A11y| UpdateButton["Update button_arch.md"]
    CheckType -->|Section layouts, button groupings, delegates| UpdateSections["Update sections_arch.md"]
    CheckType -->|Overlay container, auto-hide timing, gesture handling| UpdateBase["Update base_layout_arch.md"]
    CheckType -->|C++ state machine, React Native API, new roadmap milestones| UpdateArch["Update ARCHITECTURE.md"]
    CheckType -->|Core rules, workflow policies, new platform requirements| UpdateAgents["Update AGENTS.md"]

    UpdateTaskStatus --> SyncSummary["Sync ARCHITECTURE.md & quick-ref.md"]
    UpdateButton --> SyncSummary
    UpdateSections --> SyncSummary
    UpdateBase --> SyncSummary
    UpdateArch --> SyncSummary
    UpdateAgents --> SyncSummary
```

### Detailed Update Triggers:

0. **When Starting or Finishing ANY Task**:
   - **Update**: [TASK_STATUS.md](file:///Users/ashokammineni/video-player/new_2/Player/TASK_STATUS.md) (Set to `[IN PROGRESS]` at start, and `[COMPLETED]` with milestone updates upon completion).

1. **If you modify Button logic / styling**:
   - **Files**: `CommonButton.h`, `CommonButton.m`, `CommonButton.kt`
   - **Update**: [button_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/button_arch.md) (Section 2, 4, or 6).

2. **If you add/modify a Section (`TopSection`, `CenterSection`, `BottomSection`)**:
   - **Files**: `CenterSection.*`, `TopSection.*`, `BottomSection.*`
   - **Update**: [sections_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/sections_arch.md) (Update Section 3 roles, Section 4 delegates, and Section 8 status checklist).

3. **If you modify the Master Overlay (`ControlLayer`) or Auto-Hide rules**:
   - **Files**: `ControlLayer.h`, `ControlLayer.mm`, `ControlLayer.kt`
   - **Update**: [base_layout_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/base_layout_arch.md) (Update Section 4 lifecycle states or Section 6 mapping).

4. **If you modify Headless Playback Core logic (State machine, Commands, Observers)**:
   - **Files**: `PlayerStateCoordinator.*`, `AVPlayerAdapter.*`, `BasePlayer.*`
   - **Update**: [core_player_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/core_player_arch.md) & [state_manager_arch.md](file:///Users/ashokammineni/video-player/new_2/Player/state_manager_arch.md).

5. **If you make System-Level Architectural or Roadmap changes**:
   - **Files**: C++ core, Fabric specs, platform engine bridges, or new milestones.
   - **Update**: [ARCHITECTURE.md](file:///Users/ashokammineni/video-player/new_2/Player/ARCHITECTURE.md) (Update Section 2 diagrams, Section 4 specs, or Section 6 implementation inventory) & [TASK_STATUS.md](file:///Users/ashokammineni/video-player/new_2/Player/TASK_STATUS.md).

6. **If you modify Operational or Engineering Rules**:
   - **Update**: [AGENTS.md](file:///Users/ashokammineni/video-player/new_2/Player/AGENTS.md) (Update policies or principles).

---

## 3. Active Code Inventory (Clickable File Links)

### Shared C++ Headless Core
- **Type Definitions**: [PlayerTypes.hpp](file:///Users/ashokammineni/video-player/new_2/Player/cpp/PlayerTypes.hpp)
- **Observer Interface**: [IPlayerStateObserver.hpp](file:///Users/ashokammineni/video-player/new_2/Player/cpp/IPlayerStateObserver.hpp)
- **Engine Bridge Contract**: [IPlaybackEngineBridge.hpp](file:///Users/ashokammineni/video-player/new_2/Player/cpp/IPlaybackEngineBridge.hpp)
- **State Coordinator**: [PlayerStateCoordinator.hpp](file:///Users/ashokammineni/video-player/new_2/Player/cpp/PlayerStateCoordinator.hpp) & [PlayerStateCoordinator.cpp](file:///Users/ashokammineni/video-player/new_2/Player/cpp/PlayerStateCoordinator.cpp)

### iOS / tvOS Components
- **Playback Engine Adapter**: [AVPlayerAdapter.h](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Core/AVPlayerAdapter.h) & [AVPlayerAdapter.mm](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Core/AVPlayerAdapter.mm)
- **Network & DRM Manager**: [NetworkAuthManager.h](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Network/NetworkAuthManager.h) & [NetworkAuthManager.mm](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Network/NetworkAuthManager.mm)
- **Base Button**: [CommonButton.h](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Common/CommonButton.h) & [CommonButton.m](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Common/CommonButton.m)
- **Playback Center Section**: [CenterSection.h](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Layers/ControlLayer/CenterSection/CenterSection.h) & [CenterSection.mm](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Layers/ControlLayer/CenterSection/CenterSection.mm)
- **Master Overlay Container**: [ControlLayer.h](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Layers/ControlLayer/ControlLayer.h) & [ControlLayer.mm](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/Layers/ControlLayer/ControlLayer.mm)
- **Root Native View**: [RCTVideoPlayer.mm](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/RCTVideoPlayer.mm)

### Android / Android TV Components
- **C++ JNI Bridge**: [PlayerStateCoordinatorJni.cpp](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/jni/PlayerStateCoordinatorJni.cpp) & [CMakeLists.txt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/jni/CMakeLists.txt)
- **Coordinator Facade**: [PlayerStateCoordinator.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/core/PlayerStateCoordinator.kt) & [PlaybackState.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/core/PlaybackState.kt)
- **Network & DRM Manager**: [NetworkAuthManager.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/network/NetworkAuthManager.kt) & [DrmConfig.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/network/DrmConfig.kt) & [TokenRefreshAuthenticator.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/network/TokenRefreshAuthenticator.kt)
- **Base Button**: [CommonButton.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/ui/common/CommonButton.kt)
- **Playback Center Section**: [CenterSection.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/ui/sections/CenterSection.kt)
- **Playback Top Section**: [TopSection.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/ui/sections/TopSection.kt)
- **Playback Bottom Section**: [BottomSection.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/ui/sections/BottomSection.kt)
- **Master Overlay Container**: [ControlLayer.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/ui/ControlLayer.kt)
- **ExoPlayer Wrapper**: [BasePlayer.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/videoplayer/BasePlayer.kt)
- **Root View & Manager**: [ReactVideoPlayer.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/ReactVideoPlayer.kt) & [ReactVideoPlayerManager.kt](file:///Users/ashokammineni/video-player/new_2/Player/android/app/src/main/java/com/player/ReactVideoPlayerManager.kt)

### React Native Unified Components & Exports
- **Component Root**: [src/index.tsx](file:///Users/ashokammineni/video-player/new_2/Player/src/index.tsx) (`<VideoPlayer />`)
- **Fabric Component Spec**: [VideoPlayerNativeComponent.ts](file:///Users/ashokammineni/video-player/new_2/Player/specs/VideoPlayerNativeComponent.ts)
- **Sample Application**: [App.tsx](file:///Users/ashokammineni/video-player/new_2/Player/App.tsx)
