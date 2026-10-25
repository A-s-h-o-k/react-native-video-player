# Strict User Approval Policy
1. **Explicit Permission Required**: Never create, modify, or delete any files, or run mutating commands, without explicit prior confirmation and approval from the user.
2. **Consult First**: Always present findings, proposed diffs/plans, and design trade-offs first. Wait for the user's explicit decision before taking any action.
3. **Subagent & Session Continuity**: This rule applies strictly across all interactions, spawned subagents, and future chat sessions within this workspace.

# Core Architectural & Engineering Principles

1. **Cross-Platform (Mobile & TV First)**:
   - Always design for iOS, Android, Apple TV (tvOS), and Android TV / Fire TV.
   - Support remote/D-pad navigation, focus engines, and leanback ergonomics natively on TV platforms.

2. **Common State Machine & Shared Core**:
   - Evaluate if logic, state machines, or components can be implemented once as a shared cross-platform core (e.g. C++ player state coordinator/engine).

3. **DRY & Modular**:
   - Zero code duplication. Factor out shared patterns into common reusable classes/interfaces and extend them.

4. **Extensible (Plug-and-Play Primitives)**:
   - Build controls and overlays as modular, pluggable primitives that developers can assemble, customize, or swap without touching playback internals.

5. **Readability & Maintainability**:
   - Clean, self-explanatory, idiomatic code with clear separation of concerns.

6. **Industry Best Practices**:
   - High-performance (60/120 FPS), memory-safe, thread-safe, leak-free player lifecycles, and adherence to React Native Fabric (New Architecture) standards.

7. **Accessibility (A11y) & VoiceOver / TalkBack**:
   - Full screen-reader support: proper accessibility labels, traits, roles, and values for all buttons and sliders.
   - Dynamic announcements for state changes (e.g., "Playing", "Paused", "Seeking to 1 minute 30 seconds").
   - Large tap targets and dynamic type sizing.

8. **Voice Control, Siri/Google Assistant & Media Sessions**:
   - Integrate with OS Media Sessions (`MPRemoteCommandCenter` / `MPNowPlayingInfoCenter` on iOS/tvOS, `MediaSessionCompat` on Android/Android TV).
   - Support hardware media keys, Bluetooth remotes, headset controls, lock screen widgets, and voice commands (e.g. "Hey Siri, pause", "Hey Google, skip 30 seconds").

9. **Interruption & Audio Focus Management**:
   - Graceful handling of incoming phone calls, alarms, headphones unplugged (becoming noisy), and audio routing changes.

10. **Picture-in-Picture (PiP) & Background Playback**:
    - Architect native layers to be fully compatible with native OS Picture-in-Picture and background audio mode.

11. **Living Architecture Documentation & Task Tracking**:
    - Always check [TASK_STATUS.md](file:///Users/ashokammineni/video-player/new_2/Player/TASK_STATUS.md) first before beginning any work to understand active tasks and current status.
    - Whenever an agent begins a task, it must set the active task to `[IN PROGRESS]` in [TASK_STATUS.md](file:///Users/ashokammineni/video-player/new_2/Player/TASK_STATUS.md).
    - Whenever any task or action is completed, immediately mark it `[COMPLETED]` in [TASK_STATUS.md](file:///Users/ashokammineni/video-player/new_2/Player/TASK_STATUS.md) and synchronize all relevant architecture documentation ([ARCHITECTURE.md](file:///Users/ashokammineni/video-player/new_2/Player/ARCHITECTURE.md), [quick-ref.md](file:///Users/ashokammineni/video-player/new_2/Player/quick-ref.md), and component specs) as mandated by the project documentation map. The documentation and task status must always remain synchronized with the active codebase.
