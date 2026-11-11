import type {
  HostComponent,
  ViewProps,
} from 'react-native';
import {codegenNativeComponent} from 'react-native';
import type {
  BubblingEventHandler,
  Double,
  Int32,
  WithDefault,
} from 'react-native/Libraries/Types/CodegenTypes';

type VideoPlayer = {
  result: 'success' | 'error';
};

type FullscreenChangeEvent = {
  isFullscreen: boolean;
};

// New event types
type ProgressEvent = Readonly<{
  currentTime: Double;
  duration: Double;
  playableDuration: Double;
}>;

type LoadEvent = Readonly<{
  duration: Double;
  naturalSize: Readonly<{
    width: Double;
    height: Double;
  }>;
}>;

type ErrorEvent = Readonly<{
  code: Int32;
  message: string;
}>;

type BufferEvent = Readonly<{
  isBuffering: boolean;
}>;

export interface NativeProps extends ViewProps {
  videoUrl: string;
  title?: string;
  onScriptLoaded?: BubblingEventHandler<VideoPlayer> | null;
  seekTo?: Int32;
  play: boolean;
  onScriptLoading?: BubblingEventHandler<VideoPlayer> | null;
  onScriptError?: BubblingEventHandler<VideoPlayer> | null;
  onError?: BubblingEventHandler<VideoPlayer> | null;
  onPlay?: BubblingEventHandler<VideoPlayer> | null;
  onPause?: BubblingEventHandler<VideoPlayer> | null;
  iconSize?: Int32;
  headers?: string;
  drm?: string;
  resizeMode?: string;
  fullscreen?: boolean;
  showFullscreenButton?: WithDefault<boolean, false>;
  autoAdjustSafeArea?: boolean;
  icons?: string;
  accentColor?: string;
  trackColor?: string;
  bufferColor?: string;
  skipInterval?: WithDefault<Int32, 10>;
  showRewindButton?: WithDefault<boolean, true>;
  showForwardButton?: WithDefault<boolean, true>;
  showPlayPauseButton?: WithDefault<boolean, true>;
  autoHideTimeout?: WithDefault<Int32, 5000>;
  controls?: WithDefault<boolean, true>;
  onFullscreenChange?: BubblingEventHandler<FullscreenChangeEvent> | null;
  onProgress?: BubblingEventHandler<ProgressEvent>;
  onLoad?: BubblingEventHandler<LoadEvent>;
  onVideoError?: BubblingEventHandler<ErrorEvent>;
  onBuffer?: BubblingEventHandler<BufferEvent>;
  onEnd?: BubblingEventHandler<null>;
}

export default codegenNativeComponent<NativeProps>(
  'VideoPlayer',
) as HostComponent<NativeProps>;
