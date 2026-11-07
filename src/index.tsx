import React, { forwardRef } from 'react';
import {
  Image,
  ImageSourcePropType,
  StyleSheet,
  StyleProp,
  ViewProps,
} from 'react-native';

import VideoPlayerNativeComponent from '../specs/VideoPlayerNativeComponent';
import defaultPlayerConfig from './default-player-config.json';

export type DrmType = 'fairplay' | 'widevine' | 'clearkey';

export interface PlayerThemeConfig {
  /** Brand accent color for scrubber notch (thumb) and active progress track */
  accentColor?: string;
  /** Background timeline track color */
  trackColor?: string;
  /** Buffered chunks progress bar color */
  bufferColor?: string;
}

export interface PlayerBehaviorConfig {
  /** Seek step interval in seconds for rewind and forward buttons (default: 15) */
  skipInterval?: number;
  /** Controls overlay auto-hide inactivity timeout in milliseconds (default: 5000, 0 = always visible) */
  autoHideTimeout?: number;
  /** Whether to display the rewind button in CenterSection (default: true) */
  showRewindButton?: boolean;
  /** Whether to display the fast forward button in CenterSection (default: true) */
  showForwardButton?: boolean;
  /** Whether to display the center play/pause button (default: true) */
  showPlayPauseButton?: boolean;
  /** Whether to display the fullscreen button in BottomSection (default: false) */
  showFullscreenButton?: boolean;
  /** Whether to display the native control overlay (default: true) */
  controls?: boolean;
}

export interface PlayerConfig {
  /** Visual color theme tokens */
  theme?: PlayerThemeConfig;
  /** Complete icon replacement map (local assets, SF Symbols, drawables, or remote URLs) */
  icons?: PlayerIcons;
  /** Playback and overlay behavior configuration */
  behavior?: PlayerBehaviorConfig;
}

export interface PlayerIcons {
  /** Custom icon for Play state */
  play?: ImageSourcePropType | string;
  /** Custom icon for Pause state */
  pause?: ImageSourcePropType | string;
  /** Custom icon for Replay state (when video ends) */
  replay?: ImageSourcePropType | string;
  /** Custom icon for Rewind / Step backward */
  rewind?: ImageSourcePropType | string;
  /** Custom icon for Fast-Forward / Step forward */
  forward?: ImageSourcePropType | string;
  /** Custom icon for Enter Fullscreen */
  fullscreenEnter?: ImageSourcePropType | string;
  /** Custom icon for Exit Fullscreen */
  fullscreenExit?: ImageSourcePropType | string;
  /** Custom graphic/icon replacing the slider scrubber notch (thumb) */
  sliderThumb?: ImageSourcePropType | string;
  /** Custom icon for Back / Dismiss button */
  back?: ImageSourcePropType | string;
  /** Custom icon for Closed Captions toggle */
  captions?: ImageSourcePropType | string;
  /** Custom icon for Settings menu */
  settings?: ImageSourcePropType | string;
}

export interface DrmOptions {
  /** DRM encryption scheme ('fairplay' on iOS/tvOS, 'widevine' on Android/Fire TV) */
  type?: DrmType;
  /** License acquisition endpoint URL */
  licenseServerUrl: string;
  /** Apple FairPlay Application Certificate URL (.cer) */
  certificateUrl?: string;
  /** Custom authentication / token headers passed to license server */
  headers?: Record<string, string>;
  /** Whether to allow multiple DRM sessions for concurrent keys */
  multiSession?: boolean;
}

export interface VideoPlayerProps extends ViewProps {
  /** Media URL (HLS .m3u8, MP4, DASH .mpd, or local file) */
  videoUrl: string;
  /** Video title displayed in the top navigation overlay */
  title?: string;
  /** Declarative playback state (true = playing, false = paused) */
  play?: boolean;
  /** Scaling mode for the video surface ('contain', 'cover', 'stretch') */
  resizeMode?: 'contain' | 'cover' | 'stretch';
  /** Target aspect ratio override (e.g. 16/9, '16:9', or 1.777) */
  aspectRatio?: number | string;
  /** Seek playhead to specific second timestamp */
  seekTo?: number;
  /** Icon dimension base size in points/dp */
  iconSize?: number;
  /** Custom HTTP request headers for playlist manifest and segment chunk fetching */
  headers?: Record<string, string>;
  /** Hardware DRM configuration (FairPlay / Widevine) */
  drm?: DrmOptions;
  /** Controlled native fullscreen toggle */
  fullscreen?: boolean;
  /** Whether to render the fullscreen toggle button in BottomSection (default: false) */
  showFullscreenButton?: boolean;
  /** Smart safe area cutout clearance (default: true) */
  autoAdjustSafeArea?: boolean;
  /** Whether to auto-load configuration from the bundled default-player-config.json (default: false) */
  readFromJson?: boolean;
  /** Declarative JSON design tokens / theme configuration object */
  config?: PlayerConfig;
  /** Complete icon replacement map (local assets, SF Symbols, drawables, or remote URLs) */
  icons?: PlayerIcons;
  /** Brand accent color for scrubber notch (thumb) and active progress track */
  accentColor?: string;
  /** Background timeline track color */
  trackColor?: string;
  /** Buffered chunks progress bar color */
  bufferColor?: string;
  /** Seek step interval in seconds for rewind and forward buttons (default: 15) */
  skipInterval?: number;
  /** Whether to display the rewind button in CenterSection (default: true) */
  showRewindButton?: boolean;
  /** Whether to display the fast forward button in CenterSection (default: true) */
  showForwardButton?: boolean;
  /** Whether to display the center play/pause button (default: true) */
  showPlayPauseButton?: boolean;
  /** Controls overlay auto-hide inactivity timeout in milliseconds (default: 5000, 0 = always visible) */
  autoHideTimeout?: number;
  /** Whether to display the native control overlay (default: true). Set false for headless/custom JSX overlays. */
  controls?: boolean;
  /** Fired when native fullscreen state changes */
  onFullscreenChange?: (event: { nativeEvent: { isFullscreen: boolean } }) => void;
  /** Fired when media metadata is parsed and first frame decodes */
  onScriptLoaded?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  /** Fired during initial buffer load */
  onScriptLoading?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  /** Fired if component fails to instantiate */
  onScriptError?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  /** Fired on playback error (network stall, decoding failure, DRM rejection) */
  onError?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  /** Fired when playback transitions to Playing */
  onPlay?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  /** Fired when playback transitions to Paused */
  onPause?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
}

function serializeIcons(icons?: PlayerIcons): string | undefined {
  if (!icons) return undefined;
  const serialized: Record<string, string> = {};
  for (const [key, val] of Object.entries(icons)) {
    if (!val) continue;
    if (typeof val === 'string') {
      serialized[key] = val;
    } else {
      const resolved = Image.resolveAssetSource(val as ImageSourcePropType);
      if (resolved?.uri) {
        serialized[key] = resolved.uri;
      }
    }
  }
  return Object.keys(serialized).length > 0 ? JSON.stringify(serialized) : undefined;
}

function parseAspectRatio(ratio?: number | string): number | undefined {
  if (typeof ratio === 'number') {
    return ratio;
  }
  if (typeof ratio === 'string') {
    if (ratio.includes(':')) {
      const [w, h] = ratio.split(':').map(Number);
      if (w > 0 && h > 0) return w / h;
    } else if (ratio.includes('/')) {
      const [w, h] = ratio.split('/').map(Number);
      if (w > 0 && h > 0) return w / h;
    }
    const num = parseFloat(ratio);
    return isNaN(num) ? undefined : num;
  }
  return undefined;
}

export const VideoPlayer = forwardRef<any, VideoPlayerProps>(
  (
    {
      videoUrl,
      title,
      play = false,
      resizeMode = 'contain',
      aspectRatio,
      headers,
      drm,
      fullscreen,
      showFullscreenButton,
      autoAdjustSafeArea = true,
      readFromJson = false,
      config,
      icons,
      accentColor,
      trackColor,
      bufferColor,
      skipInterval,
      showRewindButton,
      showForwardButton,
      showPlayPauseButton,
      autoHideTimeout,
      controls = true,
      onFullscreenChange,
      style,
      ...props
    },
    ref
  ) => {
    // 1. Resolve configuration hierarchy:
    // Priority: Explicit prop > config object > defaultPlayerConfig (if readFromJson)
    const baseConfig: PlayerConfig = (readFromJson || config)
      ? {
          theme: { ...(readFromJson ? defaultPlayerConfig.theme : {}), ...(config?.theme || {}) },
          icons: { ...(readFromJson ? defaultPlayerConfig.icons : {}), ...(config?.icons || {}) },
          behavior: { ...(readFromJson ? defaultPlayerConfig.behavior : {}), ...(config?.behavior || {}) },
        }
      : {};

    const resolvedAccentColor = accentColor ?? baseConfig.theme?.accentColor;
    const resolvedTrackColor = trackColor ?? baseConfig.theme?.trackColor;
    const resolvedBufferColor = bufferColor ?? baseConfig.theme?.bufferColor;

    const mergedIcons: PlayerIcons | undefined = (icons || baseConfig.icons)
      ? { ...(baseConfig.icons || {}), ...(icons || {}) }
      : undefined;

    const resolvedSkipInterval = skipInterval ?? baseConfig.behavior?.skipInterval;
    const resolvedAutoHideTimeout = autoHideTimeout ?? baseConfig.behavior?.autoHideTimeout;
    const resolvedShowRewindButton = showRewindButton ?? baseConfig.behavior?.showRewindButton;
    const resolvedShowForwardButton = showForwardButton ?? baseConfig.behavior?.showForwardButton;
    const resolvedShowPlayPauseButton = showPlayPauseButton ?? baseConfig.behavior?.showPlayPauseButton;
    const resolvedShowFullscreenButton = showFullscreenButton ?? baseConfig.behavior?.showFullscreenButton;
    const resolvedControls = controls ?? baseConfig.behavior?.controls ?? true;

    const serializedHeaders = headers ? JSON.stringify(headers) : undefined;
    const serializedDrm = drm ? JSON.stringify(drm) : undefined;
    const serializedIcons = serializeIcons(mergedIcons);
    const computedAspectRatio = parseAspectRatio(aspectRatio);

    return (
      <VideoPlayerNativeComponent
        ref={ref}
        style={[
          styles.defaultStyle,
          computedAspectRatio ? { aspectRatio: computedAspectRatio } : null,
          style,
        ]}
        videoUrl={videoUrl}
        title={title}
        play={play}
        resizeMode={resizeMode}
        headers={serializedHeaders}
        drm={serializedDrm}
        fullscreen={fullscreen}
        showFullscreenButton={resolvedShowFullscreenButton}
        autoAdjustSafeArea={autoAdjustSafeArea}
        icons={serializedIcons}
        accentColor={resolvedAccentColor}
        trackColor={resolvedTrackColor}
        bufferColor={resolvedBufferColor}
        skipInterval={resolvedSkipInterval}
        showRewindButton={resolvedShowRewindButton}
        showForwardButton={resolvedShowForwardButton}
        showPlayPauseButton={resolvedShowPlayPauseButton}
        autoHideTimeout={resolvedAutoHideTimeout}
        controls={resolvedControls}
        onFullscreenChange={onFullscreenChange}
        {...props}
      />
    );
  }
);

const styles = StyleSheet.create({
  defaultStyle: {
    width: '100%',
    height: '100%',
    backgroundColor: '#000000',
  },
});

export default VideoPlayer;
