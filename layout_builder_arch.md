# Declarative Custom Layout Builder: Complete Architecture & Developer Specification (`layout_builder_arch.md`)

## 1. Executive Summary & Core Philosophy

The **Declarative Custom Layout Builder** is a dual-mode, schema-driven layout system that gives application developers and product teams **100% control over the video player user interface** while maintaining **native 60/120 FPS performance, memory safety, and zero JS bridge jitter**.

Instead of forcing developers to choose between an un-customizable turnkey player or building complex, laggy UI controls from scratch in React Native JSX, this system introduces a streamlined **2-Pillar Architecture**:

```
=============================================================================================
                              DEVELOPER / CONSUMER CHOICE
=============================================================================================
                 │                                                          │
   [ PILLAR 1: TURNKEY ]                                     [ PILLAR 2: CUSTOM BUILDER ]
<VideoPlayer videoUrl="..." />                         <VideoPlayer layout={myLayout} />
                 │                                                          │
                 └──────────────────────────┬───────────────────────────────┘
                                            │
                                            ▼
                       ┌─────────────────────────────────────────┐
                       │   Fast-Path Router (src/index.tsx)      │
                       │   Does props.layout exist?              │
                       └────────────────────┬────────────────────┘
                                            │
                     ┌──────────────────────┴──────────────────────┐
            NO (Fast-Path)                                   YES (Custom-Path)
                     │                                             │
                     ▼                                             ▼
   ┌───────────────────────────────────┐         ┌───────────────────────────────────┐
   │    PILLAR 1: TURNKEY NATIVE       │         │    PILLAR 2: CUSTOM BUILDER       │
   │                                   │         │                                   │
   │ • 0ms Parse Time                  │         │ • Runtime Mode: Layout Parser     │
   │ • 0KB Extra Bundle Bloat          │         │ • Build-Time Mode: AOT CLI        │
   │ • Native ControlLayer.mm / .kt    │         │ • Primitives Catalog:             │
   │   - TopSection (Title, Back)      │         │   - PlayPauseButton, Scrubber     │
   │   - CenterSection (Rewind, Play)  │         │   - TimeDisplay, Containers       │
   │   - BottomSection (Timeline)      │         │ • Custom styling & arrangements   │
   └─────────────────┬─────────────────┘         └─────────────────┬─────────────────┘
                     │                                             │
                     └──────────────────────┬──────────────────────┘
                                            │ Direct C++ / Bridge Calls
                                            ▼
=============================================================================================
                    SHARED CROSS-PLATFORM C++ CORE (cpp/)
=============================================================================================
                     ┌─────────────────────────────────────────┐
                     │       PlayerStateCoordinator.cpp        │
                     │                                         │
                     │  • Deterministic 8-State Machine        │
                     │  • 3-Phase Jitter-Free Scrub Engine     │
                     │  • std::weak_ptr Auto-Pruning Bus       │
                     └────────────────────┬────────────────────┘
                                          │
                     ┌────────────────────┴────────────────────┐
                     ▼                                         ▼
   ┌───────────────────────────────────┐     ┌───────────────────────────────────┐
   │       iOS / tvOS PLATFORM         │     │      ANDROID / TV PLATFORM        │
   │  • AVPlayer & AVPlayerLayer       │     │  • Media3 ExoPlayer & PlayerView  │
   │  • AVPlayerAdapter.mm             │     │  • BasePlayer.kt & JNI Bridge     │
   │  • Apple FairPlay Streaming DRM   │     │  • Google Widevine Modular L1/L3  │
   └───────────────────────────────────┘     └───────────────────────────────────┘
```

### Core Design Principles
1. **Zero-Cost Abstraction for Pillar 1 (Turnkey)**: Developers who do not pass a `layout` prop pay **0ms parse time** and **0KB parser bundle footprint**. The player executes via a direct fast-path into the native `ControlLayer`.
2. **Native 60/120 FPS Performance**: The markup only dictates *visual positioning and styling*. All playback mechanics, scrubber calculations, and timecode updates bind directly to the shared C++ `PlayerStateCoordinator` without JS bridge delay.
3. **Dual Execution Modes**:
   - **Runtime Mode (Server-Driven UI / SDUI)**: Parses layout JSON/XML dynamically at launch. Enables over-the-air (OTA) UI updates and A/B testing without App Store submissions.
   - **Build-Time Mode (Ahead-of-Time / AOT)**: An offline CLI script compiles layout JSON/XML into static, type-safe TypeScript JSX during development. Guarantees 0ms runtime parse latency and full compile-time type checking.
4. **Zero Primitive Duplication**: Both Pillar 1 (Turnkey) and Pillar 2 (Custom Builder) share the exact same underlying native UI primitives (`CommonButton`, scrub bar, monospaced timecode labels).

---

## 2. Layout Schema Specification (`LayoutNode`)

The universal Abstract Syntax Tree (AST) node definition used by both the Runtime Inflater and the Build-Time Compiler:

```typescript
export type ElementType =
  // Containers
  | 'PlayerOverlay'
  | 'Row'
  | 'Column'
  | 'Center'
  | 'Spacer'
  // Action Primitives
  | 'PlayPauseButton'
  | 'RewindButton'
  | 'ForwardButton'
  | 'FullscreenButton'
  | 'BackButton'
  | 'CustomButton'
  // Telemetry & Display
  | 'Title'
  | 'CurrentTime'
  | 'Duration'
  | 'RemainingTime'
  | 'Scrubber'
  | 'BufferingSpinner'
  | 'LiveBadge';

export interface LayoutStyle {
  flexDirection?: 'row' | 'column';
  justifyContent?: 'flex-start' | 'center' | 'flex-end' | 'space-between' | 'space-around';
  alignItems?: 'flex-start' | 'center' | 'flex-end' | 'stretch';
  padding?: number;
  paddingHorizontal?: number;
  paddingVertical?: number;
  margin?: number;
  gap?: number;
  position?: 'absolute' | 'relative';
  top?: number;
  bottom?: number;
  left?: number;
  right?: number;
  width?: number | string;
  height?: number | string;
  backgroundColor?: string;
  borderRadius?: number;
  color?: string;
  fontSize?: number;
  fontWeight?: 'normal' | 'bold' | '600' | '700';
  fontFamily?: string;
}

export interface LayoutNode {
  type: ElementType;
  id?: string;
  style?: LayoutStyle;
  props?: {
    interval?: number;           // Fixed step seek duration in seconds (default: 15)
    size?: 'small' | 'medium' | 'large' | number;
    accentColor?: string;        // Scrubber thumb and progress fill
    trackColor?: string;         // Scrubber background track
    action?: string;             // Custom action ID fired to onAction(actionId)
    icon?: string;               // SF Symbol / Android Vector icon name
    label?: string;              // Custom text label
    autoHide?: number;           // Inactivity timeout in ms (default: 5000, 0 = disabled)
    [key: string]: any;
  };
  children?: LayoutNode[];
}
```

---

## 3. Markup Format Representations

Developers can author layouts in either **JSON** (zero-dependency, native parsing) or **XML** (tag-based markup):

### Format A: JSON Schema (`cinema_layout.json`)
```json
{
  "type": "PlayerOverlay",
  "props": { "autoHide": 5000 },
  "children": [
    {
      "type": "Row",
      "id": "top_bar",
      "style": { "padding": 16, "justifyContent": "space-between", "alignItems": "center" },
      "children": [
        { "type": "BackButton", "id": "back_btn" },
        { "type": "Title", "style": { "color": "#FFFFFF", "fontSize": 16, "fontWeight": "bold" } },
        { "type": "CustomButton", "id": "settings_btn", "props": { "icon": "gear", "action": "open_settings" } }
      ]
    },
    {
      "type": "Center",
      "children": [
        {
          "type": "Row",
          "style": { "alignItems": "center", "gap": 28 },
          "children": [
            { "type": "RewindButton", "props": { "interval": 15, "size": "medium" } },
            { "type": "PlayPauseButton", "props": { "size": "large" } },
            { "type": "ForwardButton", "props": { "interval": 15, "size": "medium" } }
          ]
        }
      ]
    },
    {
      "type": "Row",
      "id": "bottom_bar",
      "style": { "padding": 16, "alignItems": "center", "gap": 12 },
      "children": [
        { "type": "CurrentTime", "style": { "color": "#FFFFFF", "fontFamily": "monospace" } },
        { "type": "Scrubber", "style": { "width": "100%" }, "props": { "accentColor": "#E50914" } },
        { "type": "Duration", "style": { "color": "#AAAAAA", "fontFamily": "monospace" } },
        { "type": "FullscreenButton" }
      ]
    }
  ]
}
```

### Format B: Mini XML Markup (`reels_layout.xml` - TikTok Style)
```xml
<PlayerOverlay autoHide="0">
  <!-- Right Action Rail -->
  <Column style="position: absolute; right: 16; bottom: 80; gap: 20">
    <CustomButton id="like" icon="heart" label="14.2k" action="like_video" />
    <CustomButton id="comment" icon="bubble" label="428" action="open_comments" />
    <CustomButton id="share" icon="square.and.arrow.up" label="Share" action="share_video" />
  </Column>

  <!-- Big Center Tap Area -->
  <Center>
    <PlayPauseButton size="large" />
  </Center>

  <!-- Ultra-thin bottom progress track -->
  <Scrubber accentColor="#FFFFFF" trackColor="#444444" style="position: absolute; bottom: 0; left: 0; right: 0; height: 3" />
</PlayerOverlay>
```

---

## 4. Dual-Mode Processing Architecture (Runtime vs. Build-Time)

```
LAYOUT SOURCE:  player_layout.json   OR   player_layout.xml
─────────────────────────────────────────────────────────────────────────────────────────────

MODE A: RUNTIME INFLATER (Server-Driven UI / Dynamic)
─────────────────────────────────────────────────────
  [ Layout File ] ──▶ [ App Mounts ] ──▶ [ LayoutParser.tsx ] ──▶ [ Dynamic UI (60 FPS) ]
       ▲
       │ (Can be fetched dynamically from remote CDN/API over-the-air!)
  • Best for: Over-The-Air UI updates, A/B testing, multi-tenant B2B white-labeling.
  • Overhead: ~1 to 2ms on mount.

MODE B: BUILD-TIME COMPILER (Ahead-of-Time CLI)
───────────────────────────────────────────────
  [ Layout File ] ──▶ [ npx player-cli ] ──▶ [ CustomPlayer.tsx ] ──▶ [ Metro Production Bundle ]
                             ▲
                             │ (Runs on developer machine during build)
  • Best for: Apps that require 0ms parse time, 0KB runtime parser, and compile-time TS checks.
  • Overhead: 0ms on device, 0KB parser in app bundle.
```

---

## 5. Screen Layer & Z-Index Visual Hierarchy

How views stack on the physical device screen:

```
┌───────────────────────────────────────────────────────────────────────────────────────────┐
│ Z: 2  CUSTOM / DECLARED UI CONTROLS LAYER                                                 │
│       ┌───────────────────────────────────────────────────────────────────────────┐       │
│       │ TopBar: [Back Button]            [Video Title]                 [Settings] │       │
│       └───────────────────────────────────────────────────────────────────────────┘       │
│                                                                                           │
│       ┌───────────────────────────────────────────────────────────────────────────┐       │
│       │ CenterCluster:         [Rewind 15s]    [ ▶ / ⏸ ]    [Forward 15s]         │       │
│       └───────────────────────────────────────────────────────────────────────────┘       │
│                                                                                           │
│       ┌───────────────────────────────────────────────────────────────────────────┐       │
│       │ BottomBar: [01:24] ────[●════════════════════════════]──── [45:10]  [ ⛶ ] │       │
│       └───────────────────────────────────────────────────────────────────────────┘       │
├───────────────────────────────────────────────────────────────────────────────────────────┤
│ Z: 1  GESTURE & CONTRAST INTERCEPTOR                                                      │
│       • Top & Bottom dark gradient scrims (sized dynamically to Safe Area insets)         │
│       • Background tap-to-toggle visibility gesture listener                              │
│       • Smart 5-second auto-hide lifecycle with pause and scrub immunity                  │
├───────────────────────────────────────────────────────────────────────────────────────────┤
│ Z: 0  NATIVE HARDWARE VIDEO SURFACE                                                       │
│       • iOS: AVPlayerLayer (Metal hardware rendering)                                     │
│       • Android: PlayerView / SurfaceView (Hardware TEE video decoding)                   │
└───────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. High-Frequency vs. Low-Frequency Dual-Lane Performance Loop

```
[ USER TOUCH / SCRUB ]
         │
         │  (Lane 1: 100% Native High-Frequency Loop @ 60/120 FPS, 0ms Delay)
         ▼
┌──────────────────┐       scrubTo(time)       ┌────────────────────────┐
│  Overlay View    │ ────────────────────────▶ │ C++ State Coordinator  │
│  (Custom / Native│ ◀──────────────────────── │ (3-Phase Scrub Engine) │
└──────────────────┘     onTimeUpdated()       └───────────┬────────────┘
         ▲               (std::weak_ptr bus)               │
         │                                                 │ executeSeek()
         │                                                 ▼
         │                                     ┌────────────────────────┐
         │                                     │ AVPlayer / ExoPlayer   │
         │                                     │ Hardware Engine        │
         │                                     └────────────────────────┘
         │
         │  (Lane 2: Low-Frequency Async Telemetry Throttled @ 250ms - 1000ms)
         ▼
┌────────────────────────────────────────────────────────────────────────┐
│ REACT NATIVE JS THREAD                                                 │
│ • onProgress({ currentTime, duration, bufferedTime })                  │
│ • Analytics heartbeats, watch history persistence, telemetry plugins   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Primitive Component Registry

The runtime and compile-time systems map node types to high-performance UI primitives wired to the player state bus:

```typescript
// src/dynamic/registry.ts
import { PlayPauseButton, RewindButton, ForwardButton, FullscreenButton, BackButton, CustomButton } from './primitives/Buttons';
import { Scrubber } from './primitives/Scrubber';
import { CurrentTime, Duration, RemainingTime } from './primitives/TimeDisplay';
import { Title } from './primitives/Title';
import { PlayerOverlay, Row, Column, Center, Spacer } from './primitives/Containers';

export const PRIMITIVE_REGISTRY: Record<string, React.ComponentType<any>> = {
  PlayerOverlay,
  Row,
  Column,
  Center,
  Spacer,
  PlayPauseButton,
  RewindButton,
  ForwardButton,
  FullscreenButton,
  BackButton,
  CustomButton,
  Title,
  CurrentTime,
  Duration,
  RemainingTime,
  Scrubber,
};
```

---

## 8. Developer Usage Recipes

### Recipe 1: Turnkey Default (1 Line of Code)
```tsx
import React from 'react';
import { VideoPlayer } from 'react-native-video-player';

export function TurnkeyPlayer() {
  return (
    <VideoPlayer 
      videoUrl="https://stream.example.com/movie.mp4" 
      title="Interstellar (4K)" 
    />
  );
}
```

### Recipe 2: Custom JSON Layout (Runtime Mode)
```tsx
import React from 'react';
import { VideoPlayer } from 'react-native-video-player';
import cinemaLayout from './layouts/cinema_layout.json';

export function CinemaPlayer() {
  return (
    <VideoPlayer 
      videoUrl="https://stream.example.com/movie.mp4" 
      layout={cinemaLayout}
      onAction={(actionId) => {
        if (actionId === 'open_settings') openSettingsModal();
      }}
    />
  );
}
```

### Recipe 3: Pre-Compiled AOT Layout (Build-Time Mode)
Compile with the CLI:
```bash
npx player-cli compile ./layouts/cinema_layout.json --out ./components/CompiledCinemaPlayer.tsx
```
Consume in React Native:
```tsx
import React from 'react';
import { CompiledCinemaPlayer } from './components/CompiledCinemaPlayer';

export function ProductionApp() {
  return (
    <CompiledCinemaPlayer 
      videoUrl="https://stream.example.com/movie.mp4" 
      onAction={(actionId) => console.log('Action:', actionId)} 
    />
  );
}
```

---

## 9. Implementation Roadmap & Verification Checklist

- [ ] **Phase 1: Native Aperture & Fast-Path Routing**
  - [ ] Add `controls?: boolean` to [specs/VideoPlayerNativeComponent.ts](file:///Users/ashokammineni/video-player/new_2/Player/specs/VideoPlayerNativeComponent.ts).
  - [ ] If `controls == NO`: hide or skip instantiating `ControlLayer` in [RCTVideoPlayer.mm](file:///Users/ashokammineni/video-player/new_2/Player/ios/VideoPlayer/RCTVideoPlayer.mm) and `ReactVideoPlayer.kt`.
  - [ ] Allow React child views to render over the video surface at `zPosition = 1`.
  - [ ] Add fast-path routing in [src/index.tsx](file:///Users/ashokammineni/video-player/new_2/Player/src/index.tsx) (if `!props.layout`, run direct native with 0ms parse time).
- [ ] **Phase 2: Primitives Catalog & State Context**
  - [ ] Create `src/dynamic/context/VideoPlayerContext.tsx`.
  - [ ] Create `src/dynamic/primitives/Buttons.tsx`.
  - [ ] Create `src/dynamic/primitives/Scrubber.tsx` wired to C++ 3-phase scrub engine.
  - [ ] Create `src/dynamic/primitives/TimeDisplay.tsx`.
  - [ ] Create `src/dynamic/primitives/Containers.tsx`.
  - [ ] Create `src/dynamic/registry.ts`.
- [ ] **Phase 3: Runtime Schema Inflater**
  - [ ] Create `src/dynamic/LayoutParser.tsx`.
  - [ ] Create `src/dynamic/xmlParser.ts`.
  - [ ] Connect `layout` and `onAction` props in [src/index.tsx](file:///Users/ashokammineni/video-player/new_2/Player/src/index.tsx).
- [ ] **Phase 4: Build-Time AOT Transpiler**
  - [ ] Create `scripts/compile-layout.ts` CLI tool.
  - [ ] Add `compile:layout` script in `package.json`.
- [ ] **Phase 5: Verification & Testing**
  - [ ] Verify iOS build succeeds with `xcodebuild` (Exit code 0).
  - [ ] Verify Android build succeeds with `./gradlew assembleDebug` (Exit code 0).
  - [ ] Verify Tier 1 Turnkey player operates with 0ms parse overhead.
  - [ ] Verify Custom Layout renders accurately with 60fps scrubbing.
