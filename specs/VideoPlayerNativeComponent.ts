import type {
  CodegenTypes,
  HostComponent,
  ViewProps,
} from 'react-native';
import {codegenNativeComponent} from 'react-native';
import { Int32,  } from 'react-native/Libraries/Types/CodegenTypes';

type VideoPlayer = {
  result: 'success' | 'error';
};

type FullscreenChangeEvent = {
  isFullscreen: boolean;
};

export interface NativeProps extends ViewProps {
  videoUrl: string;
  title?: string;
  onScriptLoaded?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  seekTo?: Int32;
  play: boolean;
  onScriptLoading?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  onScriptError?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  onError?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  onPlay?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  onPause?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  iconSize?: Int32;
  headers?: string;
  drm?: string;
  resizeMode?: string;
  fullscreen?: boolean;
  showFullscreenButton?: boolean;
  autoAdjustSafeArea?: boolean;
  icons?: string;
  accentColor?: string;
  trackColor?: string;
  bufferColor?: string;
  skipInterval?: Int32;
  showRewindButton?: boolean;
  showForwardButton?: boolean;
  showPlayPauseButton?: boolean;
  autoHideTimeout?: Int32;
  controls?: boolean;
  onFullscreenChange?: CodegenTypes.BubblingEventHandler<FullscreenChangeEvent> | null;
}

export default codegenNativeComponent<NativeProps>(
  'VideoPlayer',
) as HostComponent<NativeProps>;