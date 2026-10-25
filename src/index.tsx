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

export const VideoPlayer = forwardRef<any, VideoPlayerProps>(
  ({ videoUrl, title, play = false, headers, drm, style, ...props }, ref) => {
    const serializedHeaders = headers ? JSON.stringify(headers) : undefined;
    const serializedDrm = drm ? JSON.stringify(drm) : undefined;

    return (
      <VideoPlayerNativeComponent
        ref={ref}
        style={[styles.defaultStyle, style]}
        videoUrl={videoUrl}
        title={title}
        play={play}
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
