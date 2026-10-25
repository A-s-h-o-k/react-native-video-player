import React, { forwardRef } from 'react';
import {
  StyleSheet,
  ViewStyle,
  StyleProp,
  requireNativeComponent,
  ViewProps,
} from 'react-native';

import VideoPlayerNativeComponent from '../specs/VideoPlayerNativeComponent';

export interface DrmOptions {
  type?: 'fairplay' | 'widevine';
  licenseServerUrl: string;
  certificateUrl?: string; // FairPlay only
  headers?: Record<string, string>;
  multiSession?: boolean;
}

export interface VideoPlayerProps extends ViewProps {
  videoUrl: string;
  title?: string;
  play?: boolean;
  resizeMode?: 'contain' | 'cover' | 'stretch';
  aspectRatio?: number | string;
  seekTo?: number;
  iconSize?: number;
  headers?: Record<string, string>;
  drm?: DrmOptions;
  style?: StyleProp<ViewStyle>;
  onScriptLoaded?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onScriptLoading?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onScriptError?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onError?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onPlay?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
  onPause?: (event: { nativeEvent: { result: 'success' | 'error' } }) => void;
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
      style,
      ...props
    },
    ref
  ) => {
    const serializedHeaders = headers ? JSON.stringify(headers) : undefined;
    const serializedDrm = drm ? JSON.stringify(drm) : undefined;
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
        resizeMode={"stretch"}
        headers={serializedHeaders}
        drm={serializedDrm}
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
