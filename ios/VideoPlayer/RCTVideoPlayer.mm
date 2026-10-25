//
//  RCTVideoPlayer.mm
//  Player
//
//  Created by Ashok Ammineni on 16/12/25.
//

#import "RCTVideoPlayer.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <React/RCTLog.h>

#import <react/renderer/components/AppSpec/ComponentDescriptors.h>
#import <react/renderer/components/AppSpec/EventEmitters.h>
#import <react/renderer/components/AppSpec/Props.h>
#import <react/renderer/components/AppSpec/RCTComponentViewHelpers.h>

#import <React/RCTFabricComponentsPlugins.h>

#import "ControlLayer.h"
#import "Core/AVPlayerAdapter.h"
#import "../../cpp/PlayerStateCoordinator.hpp"

using namespace facebook::react;

@interface RCTVideoPlayer () <RCTVideoPlayerViewProtocol> {
    std::unique_ptr<PlayerCore::PlayerStateCoordinator> _coordinator;
}

@property (nonatomic, strong, nullable) AVPlayer *player;
@property (nonatomic, strong, nullable) AVPlayerLayer *playerLayer;
@property (nonatomic, strong, nullable) ControlLayer *controlsLayer;
@property (nonatomic, strong, nullable) AVPlayerAdapter *adapter;
@property (nonatomic, copy, nullable) NSString *currentVideoUrl;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *drmConfig;

@end

@implementation RCTVideoPlayer

+ (void)load {
  [super load];
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<VideoPlayerComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const VideoPlayerProps>();
    _props = defaultProps;

    self.backgroundColor = UIColor.blackColor;
    _coordinator = std::make_unique<PlayerCore::PlayerStateCoordinator>();
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &oldViewProps = *std::static_pointer_cast<VideoPlayerProps const>(_props);
  const auto &newViewProps = *std::static_pointer_cast<VideoPlayerProps const>(props);

  // 1. Headers Update
  if (oldViewProps.headers != newViewProps.headers || !self.headers) {
    if (!newViewProps.headers.empty()) {
      NSData *data = [NSData dataWithBytes:newViewProps.headers.data() length:newViewProps.headers.size()];
      id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
      if ([json isKindOfClass:[NSDictionary class]]) {
        self.headers = (NSDictionary<NSString *, NSString *> *)json;
      }
    } else {
      self.headers = nil;
    }
  }

  // 2. DRM Config Update
  if (oldViewProps.drm != newViewProps.drm || !self.drmConfig) {
    if (!newViewProps.drm.empty()) {
      NSData *data = [NSData dataWithBytes:newViewProps.drm.data() length:newViewProps.drm.size()];
      id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
      if ([json isKindOfClass:[NSDictionary class]]) {
        self.drmConfig = (NSDictionary<NSString *, id> *)json;
      }
    } else {
      self.drmConfig = nil;
    }
  }

  // 3. Video URL Update - reload if player is nil (e.g., after unmount / recycle) or URL changed
  BOOL needsLoadVideo = (!self.player || oldViewProps.videoUrl != newViewProps.videoUrl) && !newViewProps.videoUrl.empty();
  if (needsLoadVideo) {
    NSString *urlStr = [NSString stringWithUTF8String:newViewProps.videoUrl.c_str()];
    [self loadVideoURLString:urlStr];
  } else if (self.adapter) {
    [self.adapter configureHeaders:self.headers drmConfig:self.drmConfig];
  }

  // 4. Play / Pause prop
  if (_coordinator) {
    if (oldViewProps.play != newViewProps.play || needsLoadVideo) {
      if (newViewProps.play) {
        _coordinator->requestPlay();
      } else {
        _coordinator->requestPause();
      }
    }
  }

  // 5. Direct SeekTo prop
  if (oldViewProps.seekTo != newViewProps.seekTo && newViewProps.seekTo >= 0 && _coordinator) {
    _coordinator->requestSeek((double)newViewProps.seekTo);
  }

  // 6. Video Title Update
  if (self.controlsLayer && (oldViewProps.title != newViewProps.title || needsLoadVideo)) {
    NSString *titleStr = [NSString stringWithUTF8String:newViewProps.title.c_str()];
    [self.controlsLayer setTitle:titleStr];
  }

  // 7. Video Gravity / ResizeMode Update
  if (oldViewProps.resizeMode != newViewProps.resizeMode || needsLoadVideo) {
    if (newViewProps.resizeMode == "cover") {
      self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    } else if (newViewProps.resizeMode == "stretch") {
      self.playerLayer.videoGravity = AVLayerVideoGravityResize;
    } else {
      self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    }
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)loadVideoURLString:(NSString *)urlString {
  if ([_currentVideoUrl isEqualToString:urlString] && self.player != nil) {
    return;
  }
  _currentVideoUrl = [urlString copy];

  [self cleanup];

  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) {
    RCTLogError(@"[VideoPlayer] Invalid URL: %@", urlString);
    [self emitResult:@"error"];
    return;
  }

  // 1. Recreate Coordinator & Engine Adapter
  _coordinator = std::make_unique<PlayerCore::PlayerStateCoordinator>();
  self.adapter = [[AVPlayerAdapter alloc] initWithCoordinator:_coordinator.get()];
  [self.adapter configureHeaders:self.headers drmConfig:self.drmConfig];
  [self.adapter loadURL:url];
  self.player = self.adapter.player;

  // 2. Video Render Surface (AVPlayerLayer)
  self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
  const auto &props = *std::static_pointer_cast<VideoPlayerProps const>(_props);
  if (props.resizeMode == "cover") {
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
  } else if (props.resizeMode == "stretch") {
    self.playerLayer.videoGravity = AVLayerVideoGravityResize;
  } else {
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
  }
  self.playerLayer.zPosition = 0;
  self.playerLayer.frame = self.bounds;
  [self.layer addSublayer:self.playerLayer];

  // 3. Control Overlay Layer
  self.controlsLayer = [[ControlLayer alloc] initWithFrame:self.bounds];
  [self.controlsLayer setCoordinator:_coordinator.get()];
  [self.controlsLayer setVideoPlayer:self.player];
  self.controlsLayer.layer.zPosition = 1;
  [self addSubview:self.controlsLayer];

  [NSLayoutConstraint activateConstraints:@[
    [self.controlsLayer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    [self.controlsLayer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [self.controlsLayer.topAnchor constraintEqualToAnchor:self.topAnchor],
    [self.controlsLayer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
  ]];

  if (!props.title.empty()) {
    [self.controlsLayer setTitle:[NSString stringWithUTF8String:props.title.c_str()]];
  }
  if (props.play) {
    _coordinator->requestPlay();
  }

  [self emitResult:@"success"];
}

- (void)emitResult:(NSString *)result {
  if (_eventEmitter) {
    auto videoPlayerEventEmitter = std::static_pointer_cast<VideoPlayerEventEmitter const>(_eventEmitter);
    VideoPlayerEventEmitter::OnScriptLoaded event;
    event.result = [result isEqualToString:@"success"] 
      ? VideoPlayerEventEmitter::OnScriptLoadedResult::Success 
      : VideoPlayerEventEmitter::OnScriptLoadedResult::Error;
    videoPlayerEventEmitter->onScriptLoaded(event);
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.playerLayer.frame = self.bounds;
  self.controlsLayer.frame = self.bounds;
}

- (void)cleanup {
  if (self.adapter) {
    [self.adapter cleanup];
    self.adapter = nil;
  }

  if (self.controlsLayer) {
    [self.controlsLayer setCoordinator:nil];
    [self.controlsLayer removeFromSuperview];
    self.controlsLayer = nil;
  }

  if (self.playerLayer) {
    self.playerLayer.player = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
  }

  if (self.player) {
    [self.player pause];
    self.player = nil;
  }
  _coordinator = nullptr;
}

- (void)prepareForRecycle {
  [super prepareForRecycle];
  [self cleanup];
  _currentVideoUrl = nil;
  self.headers = nil;
  self.drmConfig = nil;
  static const auto defaultProps = std::make_shared<const VideoPlayerProps>();
  _props = defaultProps;
}

- (void)dealloc {
  [self cleanup];
}

@end

Class<RCTComponentViewProtocol> VideoPlayerCls(void) {
  return RCTVideoPlayer.class;
}
