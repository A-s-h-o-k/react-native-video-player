# React Native Video Player: Usage Guide & API Reference (`USAGE_GUIDE.md`)

This guide provides comprehensive instructions on how to consume `<VideoPlayer />` in your React Native application, including all available props, options, event handlers, and practical code recipes.

---

## 1. Quick Start

### Basic Import & Usage

```tsx
import React, { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { VideoPlayer } from './src';

export default function App() {
  const [isPlaying, setIsPlaying] = useState(true);

  return (
    <View style={styles.container}>
      <VideoPlayer
        videoUrl="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        title="Big Buck Bunny (720p)"
        play={isPlaying}
        style={styles.player}
        onScriptLoaded={() => console.log('Video ready to play')}
        onError={({ nativeEvent }) => console.error('Playback error:', nativeEvent.result)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000000',
    justifyContent: 'center',
  },
  player: {
    width: '100%',
    height: 260, // Or aspect ratio 16 / 9
  },
});
```

---

## 2. Props Reference Table

All props are passed directly to `<VideoPlayer />` in JSX:

| Prop | Type | Default | Required | Description |
| :--- | :--- | :---: | :---: | :--- |
| **`videoUrl`** | `string` | — | **Yes** | The remote HTTP/HTTPS video stream (HLS `.m3u8`, MP4, WebM, DASH) or local file URI. |
| **`title`** | `string` | `""` | No | Video title displayed in the top navigation bar (`TopSection`). Updates dynamically without restarting playback. |
| **`play`** | `boolean` | `false` | No | Controls playback state (`true` = playing, `false` = paused). Updates trigger the shared C++ `requestPlay()` or `requestPause()`. |
| **`seekTo`** | `number` | — | No | Direct seek target timestamp in seconds (e.g. `seekTo={120}` seeks directly to 2 minutes). |
| **`style`** | `StyleProp<ViewStyle>` | `{ width: '100%', height: '100%' }` | No | Container styling. Use for sizing (width, height, aspect ratio), positioning, and borders. |
| **`iconSize`** | `number` | `48` | No | Custom base dimension for control button icons. |
| **`headers`** | `Record<string, string>` | — | No | Custom HTTP request headers (e.g. `Authorization: "Bearer ..."`), automatically attached to manifest and chunk requests. |
| **`drm`** | `DrmOptions` | — | No | Hardware DRM configuration for Apple FairPlay Streaming (iOS/tvOS) or Google Widevine Modular (Android/Fire TV). |

---

## 3. Event Callbacks Reference Table

All events emit standard React Native bubbling events containing `{ nativeEvent: { result: 'success' | 'error' } }`:

| Callback Prop | Trigger Timing | Use Case |
| :--- | :--- | :--- |
| **`onScriptLoaded`** | Fired when the video manifest and metadata are parsed, and the first frame is decoded into memory. | Hide initial loading skeletons; enable custom external control buttons. |
| **`onPlay`** | Fired when playback transitions into the active `Playing` state and frames render. | Start watch-time telemetry; pause background audio feeds. |
| **`onPause`** | Fired when playback transitions to `Paused`. | Track user pause analytics; pause telemetry timers. |
| **`onError`** | Fired when an unrecoverable network stall, invalid media URL, or decoder failure occurs. | Render a fallback error UI or trigger an automated retry. |
| **`onScriptLoading`** | Fired during initial media buffer acquisition. | Display pre-buffering animations or loaders. |
| **`onScriptError`** | Fired if the underlying native component fails to instantiate. | Fallback telemetry logging. |

---

## 4. Practical Code Recipes

### Recipe 1: 16:9 Responsive Video Aspect Ratio
Use React Native’s `aspectRatio` style property to keep videos properly proportioned across phones, tablets, and TV screens:

```tsx
import React from 'react';
import { StyleSheet, View } from 'react-native';
import { VideoPlayer } from './src';

export function ResponsivePlayer({ url, title }: { url: string; title: string }) {
  return (
    <View style={styles.card}>
      <VideoPlayer
        videoUrl={url}
        title={title}
        play={true}
        style={styles.player}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    width: '100%',
    maxWidth: 800,
    alignSelf: 'center',
    backgroundColor: '#111',
    borderRadius: 12,
    overflow: 'hidden',
  },
  player: {
    width: '100%',
    aspectRatio: 16 / 9,
  },
});
```

---

### Recipe 2: Controlling Playback from External UI Buttons
You can drive playback declaratively using standard React state:

```tsx
import React, { useState } from 'react';
import { View, Button, StyleSheet } from 'react-native';
import { VideoPlayer } from './src';

export function ControlledPlayer() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [seekTime, setSeekTime] = useState<number | undefined>(undefined);

  return (
    <View style={styles.container}>
      <VideoPlayer
        videoUrl="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        title="Controlled Demo"
        play={isPlaying}
        seekTo={seekTime}
        style={styles.player}
      />

      <View style={styles.buttonRow}>
        <Button
          title={isPlaying ? "Pause" : "Play"}
          onPress={() => setIsPlaying(prev => !prev)}
        />
        <Button
          title="Jump to 1:00"
          onPress={() => setSeekTime(60)}
        />
        <Button
          title="Restart"
          onPress={() => setSeekTime(0)}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000', padding: 16 },
  player: { width: '100%', height: 260 },
  buttonRow: { flexDirection: 'row', justifyContent: 'space-around', marginTop: 16 },
});
```

---

### Recipe 3: Dynamic Playlist / Stream Switching
Switching videos is as simple as updating the `videoUrl` prop. The C++ state coordinator will automatically reset its state machine and load the new media:

```tsx
import React, { useState } from 'react';
import { View, StyleSheet, FlatList, TouchableOpacity, Text } from 'react-native';
import { VideoPlayer } from './src';

const PLAYLIST = [
  { id: '1', title: 'Big Buck Bunny', url: 'https://lorem.video/720p' },
  { id: '2', title: 'Elephant Dream', url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4' },
];

export function PlaylistPlayer() {
  const [activeItem, setActiveItem] = useState(PLAYLIST[0]);

  return (
    <View style={styles.container}>
      <VideoPlayer
        videoUrl={activeItem.url}
        title={activeItem.title}
        play={true}
        style={styles.player}
      />

      <FlatList
        data={PLAYLIST}
        keyExtractor={item => item.id}
        renderItem={({ item }) => (
          <TouchableOpacity
            style={[styles.item, item.id === activeItem.id && styles.activeItem]}
            onPress={() => setActiveItem(item)}
          >
            <Text style={styles.itemText}>{item.title}</Text>
          </TouchableOpacity>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  player: { width: '100%', height: 260 },
  item: { padding: 16, borderBottomWidth: 1, borderBottomColor: '#333' },
  activeItem: { backgroundColor: '#222' },
  itemText: { color: '#FFF', fontSize: 16 },
});
### Recipe 5: Authenticated Streams & Hardware DRM (FairPlay / Widevine)
Pass custom headers for authenticated CDN chunks and hardware DRM options:

```tsx
import React from 'react';
import { StyleSheet, View, Platform } from 'react-native';
import { VideoPlayer } from './src';

export function ProtectedStreamPlayer() {
  const isIOS = Platform.OS === 'ios';

  return (
    <View style={styles.container}>
      <VideoPlayer
        style={styles.player}
        videoUrl={
          isIOS
            ? "https://secure-stream.example.com/hls/master.m3u8"
            : "https://secure-stream.example.com/dash/stream.mpd"
        }
        title="Protected Feature Film"
        headers={{
          Authorization: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
          "X-Tenant-ID": "enterprise-client-42",
        }}
        drm={
          isIOS
            ? {
                type: "fairplay",
                licenseUrl: "https://fps.example.com/get-ckc",
                certificateUrl: "https://fps.example.com/app_cert.cer",
                headers: { "X-FairPlay-Key": "fps_secret" },
              }
            : {
                type: "widevine",
                licenseUrl: "https://wv.example.com/get-license",
                multiSession: true,
                headers: { "X-Widevine-Key": "wv_secret" },
              }
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  player: { width: '100%', height: 260 },
});
```

---

## 5. Built-In Native Behaviors (Zero Configuration Required)

When you render `<VideoPlayer />`, the following high-performance native features operate automatically:

1. **Dual-Lane 60/120 FPS Native Controls**:
   * All touch ripples, scrubbing thumbs, rewind/forward steps, and timer displays update **100% inside native views** via the shared C++ state coordinator.
   * Your JavaScript thread is never blocked, and control interactions never stutter.
2. **Smart 5-Second Inactivity Auto-Hide**:
   * While video is actively playing, control overlays smoothly fade out after 5 seconds of inactivity.
   * **Pause Immunity**: When paused, controls remain visible indefinitely so users can inspect titles or read timestamps.
   * **Scrub Immunity**: Dragging the timeline slider keeps controls visible until released.
   * **Tap-to-Toggle**: Tapping anywhere on the video surface toggles control visibility.
3. **3-Phase Jitter-Free Scrub Engine**:
   * When dragging the slider thumb, continuous time updates render smoothly at 60 FPS while deferring native hardware seeks until touch release.
   * If video was playing prior to dragging, playback resumes seamlessly on release.
4. **Apple TV & Android TV Remote D-pad Navigation**:
   * Full remote control focus engine support: default focus on center Play/Pause, with D-pad navigation across Top, Center, and Bottom sections.
5. **Screen Reader Accessibility (VoiceOver & TalkBack)**:
   * Accessible button traits, hit targets ($\ge 44\times 44\text{pt}$ on Apple, $\ge 48\times 48\text{dp}$ on Android), and semantic announcements.

---

## 6. TypeScript Types Reference

Exported from `src/index.tsx`:

```typescript
import { ViewProps, StyleProp, ViewStyle } from 'react-native';

export type DrmType = 'widevine' | 'fairplay' | 'clearkey';

export interface DrmOptions {
  type: DrmType;
  licenseUrl: string;
  headers?: Record<string, string>;
  certificateUrl?: string; // FairPlay Application Certificate (.cer)
  multiSession?: boolean;
}

export interface VideoPlayerProps extends ViewProps {
  /** Video media URL (HTTP/HTTPS stream or local path) */
  videoUrl: string;
  
  /** Title displayed in the top navigation overlay */
  title?: string;
  
  /** Declarative play/pause flag */
  play?: boolean;
  
  /** Direct seek target in seconds */
  seekTo?: number;
  
  /** Icon size override in points/dp */
  iconSize?: number;

  /** Custom HTTP request headers for manifest and media chunk fetching */
  headers?: Record<string, string>;

  /** Hardware DRM configuration (FairPlay / Widevine / ClearKey) */
  drm?: DrmOptions;
  
  /** Visual container style */
  style?: StyleProp<ViewStyle>;
  
  /** Lifecycle callbacks */
  onScriptLoaded?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onScriptLoading?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onScriptError?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onError?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onPlay?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onPause?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
}
```
