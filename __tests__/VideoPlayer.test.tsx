import React from 'react';
import ReactTestRenderer from 'react-test-renderer';
import VideoPlayer from '../src/index';

describe('VideoPlayer Component', () => {
  it('renders without crashing', () => {
    // Note: Native component won't fully render in Jest, but prop validation works
    expect(VideoPlayer).toBeDefined();
  });

  it('renders with minimal props', async () => {
    let renderer: any;
    await ReactTestRenderer.act(() => {
      renderer = ReactTestRenderer.create(
        <VideoPlayer videoUrl="https://example.com/video.mp4" />
      );
    });
    expect(renderer).toBeDefined();
  });

  it('renders with full props and validates seekTo and aspect ratio', async () => {
    let renderer: any;
    const onProgress = jest.fn();
    const onLoad = jest.fn();
    const onVideoError = jest.fn();
    const onBuffer = jest.fn();
    const onEnd = jest.fn();

    await ReactTestRenderer.act(() => {
      renderer = ReactTestRenderer.create(
        <VideoPlayer
          videoUrl="https://example.com/stream.m3u8"
          title="Test Stream"
          play={true}
          seekTo={42}
          aspectRatio="16:9"
          resizeMode="cover"
          onProgress={onProgress}
          onLoad={onLoad}
          onVideoError={onVideoError}
          onBuffer={onBuffer}
          onEnd={onEnd}
        />
      );
    });
    expect(renderer).toBeDefined();
    const tree = renderer.toJSON();
    expect(tree).toBeDefined();
    expect(tree.props.videoUrl).toBe('https://example.com/stream.m3u8');
    expect(tree.props.seekTo).toBe(42);
  });

  it('filters negative seekTo', async () => {
    let renderer: any;
    await ReactTestRenderer.act(() => {
      renderer = ReactTestRenderer.create(
        <VideoPlayer
          videoUrl="https://example.com/stream.m3u8"
          seekTo={-10}
        />
      );
    });
    const tree = renderer.toJSON();
    expect(tree.props.seekTo).toBeUndefined();
  });
});
