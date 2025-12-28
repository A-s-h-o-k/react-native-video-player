import type {
  CodegenTypes,
  HostComponent,
  ViewProps,
} from 'react-native';
import {codegenNativeComponent} from 'react-native';
import { Int32 } from 'react-native/Libraries/Types/CodegenTypes';

type VideoPlayer = {
  result: 'success' | 'error';
};

export interface NativeProps extends ViewProps {
  sourceURL?: string;
  onScriptLoaded?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  seekTo?: Int32;
  play: boolean;
  onScriptLoading?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  onScriptError?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  onError?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  onPlay?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
  onPause?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
}

export default codegenNativeComponent<NativeProps>(
  'VideoPlayer',
) as HostComponent<NativeProps>;