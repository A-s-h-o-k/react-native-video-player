import type {
  CodegenTypes,
  HostComponent,
  ViewProps,
} from 'react-native';
import {codegenNativeComponent} from 'react-native';

type VideoPlayer = {
  result: 'success' | 'error';
};

export interface NativeProps extends ViewProps {
  sourceURL?: string;
  onScriptLoaded?: CodegenTypes.BubblingEventHandler<VideoPlayer> | null;
}

export default codegenNativeComponent<NativeProps>(
  'VideoPlayer',
) as HostComponent<NativeProps>;