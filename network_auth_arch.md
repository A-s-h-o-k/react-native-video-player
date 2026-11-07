# Networking, Authorization & Hardware DRM Subsystem Architecture

## 1. Executive Summary & Core Philosophy

The **Networking, Authorization & Hardware DRM Subsystem** provides a zero-UI, enterprise-grade media acquisition pipeline for the cross-platform Video Player. It decouples high-level player control and UI overlays from the low-level, performance-critical mechanics of network request dispatching, authentication token rotation, chunk caching, and hardware-backed cryptographic key exchange.

```
+---------------------------------------------------------------------------------------+
|                                React Native JSX / Fabric                              |
|   <VideoPlayer                                                                        |
|      videoUrl="https://stream.example.com/live/master.m3u8"                          |
|      headers={{ Authorization: "Bearer eyJhbGc...", "X-Client-ID": "tvos-123" }}     |
|      drm={{ type: "fairplay", licenseUrl: "...", certificateUrl: "..." }}             |
|   />                                                                                  |
+-------------------------------------------+-------------------------------------------+
                                            |
                         Fabric Props (JSON Serialized Map)
                                            |
                +---------------------------+---------------------------+
                |                                                       |
                v                                                       v
     +---------------------+                                 +---------------------+
     |   iOS / tvOS (ObjC++)|                                 | Android / FireTV (Kt)|
     |  NetworkAuthManager  |                                 | NetworkAuthManager  |
     +----------+----------+                                 +----------+----------+
                |                                                       |
     +----------+----------+                                 +----------+----------+
     | AVContentKeySession | (FairPlay FPS)                  | DefaultDrmSessionMgr| (Widevine L1/L3)
     | AVURLAsset Headers  |                                 | OkHttp / HttpDataSrc|
     +----------+----------+                                 +----------+----------+
                |                                                       |
                v                                                       v
       [ AVPlayer Engine ]                                     [ ExoPlayer Engine ]
                \                                                       /
                 \                                                     /
                  +---------------------->+<--------------------------+
                                          |
                                [ C++ State Coordinator ]
                                          |
                                 PlaybackState::Error
                                          |
                              (401/403/DRM License Expired)
```

### Core Design Principles
1. **Zero-UI Headless Separation**: Networking and DRM logic reside strictly in platform-native network primitives, entirely decoupled from buttons, scrub bars, and touch layers.
2. **Strict Cross-Platform Parity**: Apple FairPlay Streaming (iOS/tvOS) and Google Widevine Modular (Android/Fire TV) are configured through a single unified TypeScript API (`headers`, `drm`).
3. **Hardware-Enclave Security**: Key generation occurs within the device's hardware Secure Enclave (Apple FairPlay) or Trusted Execution Environment / TEE (Android Widevine Security Level 1), guaranteeing stream decryption keys are never exposed in user-space RAM or JavaScript.
4. **Resilient Interception & Dynamic Token Refresh**: Sub-manifest and chunk downloads automatically inherit authorization headers; 401/403 HTTP errors trigger synchronized token renewals without dropping playback sessions or blanking screens.
5. **Unified Error Propagation**: Network timeouts, HTTP status failures, and DRM license rejections flow synchronously into the shared C++ `PlayerStateCoordinator` to fire standardized error payloads to React Native.

---

## 2. Component Hierarchy & Module Breakdown

The subsystem is organized into dedicated modular directories on each platform:

```
Player/
├── specs/
│   └── VideoPlayerNativeComponent.ts   # Fabric Codegen prop interface (headers, drm)
├── src/
│   └── index.tsx                       # Type-safe wrapper, DrmOptions, headers serialization
├── ios/
│   └── VideoPlayer/
│       ├── Network/
│       │   ├── NetworkAuthManager.h    # AVContentKeySessionDelegate & asset decorator
│       │   └── NetworkAuthManager.mm   # FairPlay SPC <-> CKC exchange & header injector
│       └── Core/
│           ├── AVPlayerAdapter.h       # Engine adapter holding NetworkAuthManager
│           └── AVPlayerAdapter.mm      # AVURLAsset creation & DRM session hookup
└── android/app/src/main/java/com/player/
    └── network/
        ├── DrmConfig.kt                # DrmType enum (Widevine, FairPlay, ClearKey) & config
        ├── TokenRefreshAuthenticator.kt# Thread-safe 401 token refresh & request retry
        └── NetworkAuthManager.kt       # DefaultDrmSessionManager & MediaSource builder
```

---

## 3. iOS / tvOS Implementation Architecture

### 3.1 Custom HTTP Headers & Asset Configuration
On iOS/tvOS, AVFoundation isolates media downloading inside the `mediaserverd` system daemon. HTTP headers cannot simply be attached to a global session; they must be explicitly attached to `AVURLAsset` creation options using `AVURLAssetHTTPHeaderFieldsKey`:

```objc
// ios/VideoPlayer/Network/NetworkAuthManager.mm
- (AVURLAsset *)createAssetWithURL:(NSURL *)url {
  NSMutableDictionary *options = [NSMutableDictionary dictionary];
  
  if (self.customHeaders.count > 0) {
    options[AVURLAssetHTTPHeaderFieldsKey] = self.customHeaders;
  }
  
  return [AVURLAsset URLAssetWithURL:url options:options];
}
```

This guarantees that:
- The initial master playlist (`.m3u8`) request carries custom headers.
- Media variant playlists and audio/video transport stream chunks (`.ts` / `.m4s`) carry custom headers.
- Key delivery requests via HLS `#EXT-X-KEY` carry authentication credentials.

### 3.2 Apple FairPlay Streaming (FPS) Pipeline
FairPlay uses public-key cryptography to negotiate content encryption keys inside the Apple device's Secure Enclave:

```
[AVPlayer] --------> Needs Key (EXT-X-KEY) --------> [AVContentKeySession]
                                                              |
                                                    delegate callback:
                                        contentKeySession:didProvideContentKeyRequest:
                                                              |
                                                              v
                                              Fetch Application Certificate (.cer)
                                                              |
                                                              v
                                          Make Server Playback Context (SPC) via
                                           keyRequest makeStreamingContentKeyRequestData
                                                              v
                                               POST SPC to Key Server Module (KSM)
                                              (with Authorization / Custom Headers)
                                                              |
                                                              v
                                                   Receive Content Key Context (CKC)
                                                              |
                                                              v
                                              keyRequest processContentKeyResponse:
                                                              |
                                                              v
                                          Secure Enclave decrypts audio/video frames
```

#### Detailed Execution Steps:
1. **Content Key Session Initialization**: An `AVContentKeySession` is created with key system `AVContentKeySystemFairPlayStreaming`.
2. **Asset Binding**: The asset's `AVContentKeyRecipient` (the `AVURLAssetContentKeySessionSupport`) is attached to the session before loading.
3. **Application Certificate Fetch**: The Application Certificate is fetched from `drmConfig[@"certificateUrl"]` and cached in memory.
4. **SPC Generation**: When the engine encounters an encrypted chunk, `didProvideContentKeyRequest` is invoked. The manager requests the SPC payload from the hardware enclave using `[keyRequest makeStreamingContentKeyRequestDataForApp:certificate contentIdentifier:assetId ...]`.
5. **CKC License Exchange**: The SPC is POSTed to `drmConfig[@"licenseUrl"]` with headers (`Content-Type: application/octet-stream` plus any custom DRM headers).
6. **Key Injection**: The returned CKC payload is passed to `[keyRequest processContentKeyResponse:[AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:ckcData]]`.

---

## 4. Android / Android TV Implementation Architecture

### 4.1 ExoPlayer / Media3 Network Pipeline
Android leverages AndroidX Media3 ExoPlayer with `DefaultHttpDataSource.Factory`:

```kotlin
// android/app/src/main/java/com/player/network/NetworkAuthManager.kt
val httpDataSourceFactory = DefaultHttpDataSource.Factory()
    .setUserAgent("ReactNativeVideoPlayer/1.0 (Android; Media3)")
    .setConnectTimeoutMs(15_000)
    .setReadTimeoutMs(15_000)
    .setAllowCrossProtocolRedirects(true)

headers?.let { httpDataSourceFactory.setDefaultRequestProperties(it) }
```

### 4.2 Hardware Widevine Modular DRM (L1 / L3)
Android devices support Widevine Modular via the Android HAL and hardware TrustZone / TEE:
- **Widevine L1**: Hardware video decoding and cryptographic processing inside the Trusted Execution Environment (TEE). Required for 1080p, 4K, and HDR streams.
- **Widevine L3**: Software cryptographic fallback when hardware enclave is unavailable (typically limited to 480p/576p SD playback).

```kotlin
// Widevine UUID: C.WIDEVINE_UUID (edef8ba9-79d6-4ace-a3c8-27dcd51d21ed)
val drmCallback = HttpMediaDrmCallback(drmConfig.licenseUrl, drmHttpDataSourceFactory)
drmConfig.headers?.forEach { (key, value) ->
    drmCallback.setKeyRequestProperty(key, value)
}

val drmSessionManager = DefaultDrmSessionManager.Builder()
    .setUuidAndExoMediaDrmProvider(C.WIDEVINE_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
    .setMultiSession(drmConfig.multiSession)
    .build(drmCallback)
```

### 4.3 Adaptive Media Source Factory
`NetworkAuthManager` automatically maps stream extensions to their optimized Media3 parsers:
- **HLS (`.m3u8`)**: `HlsMediaSource.Factory(dataSourceFactory).setDrmSessionManagerProvider { drmSessionManager }`
- **DASH (`.mpd`)**: `DashMediaSource.Factory(dataSourceFactory).setDrmSessionManagerProvider { drmSessionManager }`
- **SmoothStreaming (`.ism`)**: `SsMediaSource.Factory(dataSourceFactory)`
- **Progressive (MP4/WebM/MKV)**: `ProgressiveMediaSource.Factory(dataSourceFactory)`

---

## 5. Token Interception, Rotation & Auto-Refresh

### 5.1 The Stale Token Dilemma
Long-form video streams (live broadcasts, sports events, 2+ hour feature films) frequently exceed token expiration windows (e.g., JWT expiring in 15 or 30 minutes). When a manifest refresh or segment download fails with HTTP `401 Unauthorized`:
1. Traditional naive players crash or trigger a full reload, causing buffering spinners and dropped frames.
2. The `TokenRefreshAuthenticator` intercepts the 401, coordinates with the token provider service, injects the refreshed token, and replays the failed request in the background.

```
[ Chunk Fetch (T=1800s) ] ---> HTTP GET chunk_120.m4s (Bearer Token Expired)
                                           |
                                           v
                             HTTP 401 / 403 Forbidden
                                           |
                                           v
                       [ TokenRefreshAuthenticator ]
                                           |
                              Acquire Mutex / Lock
                                           |
                        Call tokenProvider.refreshToken()
                                           |
                                    Update header:
                       Authorization: Bearer <NEW_JWT>
                                           |
                         Replay HTTP GET chunk_120.m4s
                                           |
                                           v
                               HTTP 200 OK (Chunk Loaded)
                                           |
                              Seamless Video Playback
```

---

## 6. End-to-End Buffering & Error Propagation

### 6.1 Buffering Mechanics & Low-Latency Live Tuning
The player implements optimized buffer thresholds via `DefaultLoadControl` and `AVPlayerItem`:
- **Preroll to Start / Seek (`bufferForPlaybackMs`)**: 1,000 ms (playback starts after 1.0 second of media are buffered, reducing startup delay by 60%).
- **Target Buffer Maintained (`minBufferMs`)**: 15,000 ms (minimum baseline buffer maintained during playback).
- **Max Buffer (`maxBufferMs`)**: 30,000 ms (prevents runaway memory consumption, mirrored on iOS via `preferredForwardBufferDuration = 30.0`).
- **Rebuffer Threshold (`bufferForPlaybackAfterRebufferMs`)**: 3,000 ms (upon stall, engine accumulates 3 seconds before resuming).
- **Time-over-Size Prioritization**: Configured with `prioritizeTimeOverSizeThresholds(true)` to protect low-RAM devices (Fire TV / Android TV sticks) from OOM pressure.
- **Low-Latency Live Edge (LL-HLS / LL-DASH)**: Configured with 2.0s target offset and dynamic catch-up speeds (0.97x–1.05x on Android, `automaticallyPreservesTimeOffsetFromLive = YES` on iOS).

### 6.2 Network Ping (RTT) & Real-Time Bandwidth Telemetry
Zero third-party SDKs are required to measure network health. Both native engines expose chunk-level network telemetry directly to the shared C++ `PlayerStateCoordinator`:
- **Android (`AnalyticsListener.onLoadCompleted`)**: Extracts `loadEventInfo.loadDurationMs` as chunk RTT/ping and calculates real-time throughput in bps: `(bytesLoaded * 8000) / maxOf(1, loadDurationMs)`.
- **iOS (`AVPlayerItemNewAccessLogEntryNotification`)**: Reads `lastEvent.transferDuration` (chunk ping in seconds) and `lastEvent.observedBitrate` (measured bandwidth in bps).
- **Telemetry Bus**: Metrics dispatch to `PlayerStateCoordinator::notifyEngineNetworkMetrics`, updating `PlayerSnapshot.networkPingMs` and `PlayerSnapshot.bandwidthBitrateBps` with zero UI or JS thread delay.

### 6.3 In-Stream Buffer Metadata Parsers
Built-in demuxers automatically parse timed metadata without adding external libraries:
- **Android**: `Player.Listener.onMetadata(metadata)` captures parsed ID3v2 frames, SCTE-35 dynamic ad markers (`SpliceInsertCommand`), and chapter cues.
- **iOS**: `AVPlayerItemMetadataOutput` attached to `AVPlayerItem` delivers `AVTimedMetadataGroup` items as the playhead advances through the buffer.

### 6.4 Error Propagation State Machine
All networking and authorization errors are intercepted and translated into standardized C++ coordinator events:

| Failure Type | Native Root Cause | Coordinator State | React Native Event |
|---|---|---|---|
| **DNS / Offline** | `NSURLErrorCannotFindHost` / `UnknownHostException` | `PlaybackState::Error` | `{ code: 1001, message: "Host unreachable" }` |
| **HTTP 401/403** | Auth token expired or rejected by CDN | `PlaybackState::Error` | `{ code: 1002, message: "Authorization expired" }` |
| **HTTP 404** | Segment missing or stream ended | `PlaybackState::Error` | `{ code: 1003, message: "Media resource not found" }` |
| **DRM Cert Failure** | FairPlay `.cer` fetch error (HTTP 500) | `PlaybackState::Error` | `{ code: 2001, message: "DRM Certificate unavailable" }` |
| **DRM License Denial**| KSM returns 403 or empty CKC | `PlaybackState::Error` | `{ code: 2002, message: "DRM License exchange denied" }` |
| **Hardware TEE Error**| Widevine L1 provision revoked / crypto fail | `PlaybackState::Error` | `{ code: 2003, message: "Hardware key decryption failed" }` |

---

## 7. React Native Developer Guide & Examples

### 7.1 Authenticated HLS Stream with Bearer Token

```tsx
import React from 'react';
import { StyleSheet, View } from 'react-native';
import VideoPlayer from './src';

export const AuthenticatedPlayer = () => {
  return (
    <View style={styles.container}>
      <VideoPlayer
        style={styles.player}
        videoUrl="https://secure-cdn.example.com/live/stream.m3u8"
        title="Live Broadcast (Protected)"
        headers={{
          Authorization: "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
          "X-Device-Id": "ios-device-xyz",
          "X-Session-Token": "sess_987654321"
        }}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  player: { width: '100%', height: 260 },
});
```

### 7.2 Apple FairPlay Protected Stream (iOS / tvOS)

```tsx
<VideoPlayer
  style={styles.player}
  videoUrl="https://fps.example.com/hls/master.m3u8"
  title="FairPlay Encrypted Movie"
  headers={{
    Authorization: "Bearer user_token_abc"
  }}
  drm={{
    type: "fairplay",
    licenseUrl: "https://fps.example.com/license",
    certificateUrl: "https://fps.example.com/cert/app_cert.cer",
    headers: {
      "X-Custom-License-Key": "enterprise_tenant_42"
    }
  }}
/>
```

### 7.3 Google Widevine Protected Stream (Android / Fire TV)

```tsx
<VideoPlayer
  style={styles.player}
  videoUrl="https://dash.example.com/widevine/stream.mpd"
  title="Widevine L1 4K Feature"
  drm={{
    type: "widevine",
    licenseUrl: "https://proxy.example.com/widevine/license",
    multiSession: true,
    headers: {
      "PreAuthorization": "widevine_token_9988"
    }
  }}
/>
```

---

## 8. Security & Performance Best Practices

1. **Never Log Sensitive Tokens**: Authorization headers and license responses are stripped from all native logs (`RCTLog`, Android `Log.d`).
2. **Memory Safety**: DRM keys are stored only in volatile memory and handed directly to OS hardware keystores; tokens are wiped during player `cleanup()`.
3. **Cross-Platform Reusability**: All UI controls operate oblivious to whether content is clear or encrypted, ensuring zero code bloat in React Native rendering loops.
