//
//  RCTVideoPlayer.mm
//  Player
//
//  Created by Ashok Ammineni on 16/12/25.
//

#import "RCTVideoPlayer.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <React/RCTLog.h>

#import <react/renderer/components/AppSpec/ComponentDescriptors.h>
#import <react/renderer/components/AppSpec/EventEmitters.h>
#import <react/renderer/components/AppSpec/Props.h>
#import <react/renderer/components/AppSpec/RCTComponentViewHelpers.h>

#import <React/RCTFabricComponentsPlugins.h>

#import "ControlLayer.h"
#import "Core/AVPlayerAdapter.h"
#import "../../cpp/PlayerStateCoordinator.hpp"
#import "OrientationManager.h"
#import "Metadata/MediaMetadataResolver.h"
#import "Subtitles/SubtitleManager.h"
#import "Thumbnail/ThumbnailProvider.h"
#import "MediaSession/MediaSessionManager.h"

using namespace facebook::react;

#pragma mark - Orientation Manager Implementation

static UIInterfaceOrientationMask sSupportedOrientationMask = UIInterfaceOrientationMaskPortrait;

@implementation OrientationManager

+ (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return sSupportedOrientationMask;
}

+ (void)setSupportedInterfaceOrientations:(UIInterfaceOrientationMask)mask {
  sSupportedOrientationMask = mask;
}

@end

#pragma mark - Fullscreen Container View

@interface FullscreenPlayerContainerView : UIView
@property (nonatomic, weak) AVPlayerLayer *playerLayer;
@property (nonatomic, assign) BOOL autoAdjustSafeArea;
@end

@implementation FullscreenPlayerContainerView

- (void)layoutSubviews {
  [super layoutSubviews];
  if (self.playerLayer) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    UIEdgeInsets insets = self.autoAdjustSafeArea ? self.safeAreaInsets : UIEdgeInsetsZero;
    self.playerLayer.frame = UIEdgeInsetsInsetRect(self.bounds, insets);
    [CATransaction commit];
  }
}

@end

#pragma mark - RCTVideoPlayer

@interface RCTVideoPlayer () <RCTVideoPlayerViewProtocol, SubtitleManagerDelegate, MediaSessionManagerDelegate, AVPictureInPictureControllerDelegate> {
    std::unique_ptr<PlayerCore::PlayerStateCoordinator> _coordinator;
    AVPictureInPictureController *_pipController;
}

@property (nonatomic, strong, nullable) AVPlayer *player;
@property (nonatomic, strong, nullable) AVPlayerLayer *playerLayer;
@property (nonatomic, strong, nullable) ControlLayer *controlsLayer;
@property (nonatomic, strong, nullable) AVPlayerAdapter *adapter;
@property (nonatomic, copy, nullable) NSString *currentVideoUrl;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *drmConfig;
@property (nonatomic, strong, nullable) FullscreenPlayerContainerView *fullscreenContainerView;
@property (nonatomic, assign) BOOL isFullscreenActive;
@property (nonatomic, assign) BOOL isFullscreenTransitioning;
@property (nonatomic, assign) BOOL autoAdjustSafeArea;
@property (nonatomic, strong, nullable) NSArray<NSLayoutConstraint *> *controlsConstraints;
@property (nonatomic, strong) MediaMetadataResolver *metadataResolver;
@property (nonatomic, strong) SubtitleManager *subtitleManager;
@property (nonatomic, strong) ThumbnailProvider *thumbnailProvider;
@property (nonatomic, strong, nullable) MediaSessionManager *mediaSessionManager;
@property (nonatomic, strong, nullable) id timeObserverToken;

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
    _autoAdjustSafeArea = YES;
    _coordinator = std::make_unique<PlayerCore::PlayerStateCoordinator>();
    _metadataResolver = [[MediaMetadataResolver alloc] init];
    _subtitleManager = [[SubtitleManager alloc] init];
    _subtitleManager.delegate = self;
    _thumbnailProvider = [[ThumbnailProvider alloc] init];
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps {
  const auto &newViewProps = *std::static_pointer_cast<VideoPlayerProps const>(props);
  const auto *oldViewPropsPtr = oldProps ? std::static_pointer_cast<VideoPlayerProps const>(oldProps).get() : nullptr;

  // 1. Headers Update
  if (!oldViewPropsPtr || oldViewPropsPtr->headers != newViewProps.headers || !self.headers) {
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
  if (!oldViewPropsPtr || oldViewPropsPtr->drm != newViewProps.drm || !self.drmConfig) {
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

  // 3. Video URL Update - ONLY load video if URL actually changed or player is uninitialized
  NSString *newUrlStr = [NSString stringWithUTF8String:newViewProps.videoUrl.c_str()];
  BOOL urlChanged = ![_currentVideoUrl isEqualToString:newUrlStr];
  BOOL needsLoadVideo = (!self.player || urlChanged) && !newViewProps.videoUrl.empty();
  if (needsLoadVideo) {
    [self loadVideoURLString:newUrlStr];
  } else if (self.adapter) {
    [self.adapter configureHeaders:self.headers drmConfig:self.drmConfig];
  }

  // 4. Play / Pause prop
  if (_coordinator) {
    if (!oldViewPropsPtr || oldViewPropsPtr->play != newViewProps.play || needsLoadVideo) {
      if (newViewProps.play) {
        _coordinator->requestPlay();
      } else {
        _coordinator->requestPause();
      }
    }
  }

  // 5. Direct SeekTo prop
  if (oldViewPropsPtr && oldViewPropsPtr->seekTo != newViewProps.seekTo && newViewProps.seekTo >= 0 && _coordinator) {
    _coordinator->requestSeek((double)newViewProps.seekTo);
  }

  // 6. Video Title Update
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->title != newViewProps.title || needsLoadVideo)) {
    NSString *titleStr = [NSString stringWithUTF8String:newViewProps.title.c_str()];
    [self.controlsLayer setTitle:titleStr];
  }

  // 7. Video Gravity / ResizeMode Update
  if (!oldViewPropsPtr || oldViewPropsPtr->resizeMode != newViewProps.resizeMode || needsLoadVideo) {
    if (newViewProps.resizeMode == "cover") {
      self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    } else if (newViewProps.resizeMode == "stretch") {
      self.playerLayer.videoGravity = AVLayerVideoGravityResize;
    } else {
      self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    }
  }

  // 8. Fullscreen button display prop
  if (!oldViewPropsPtr || oldViewPropsPtr->showFullscreenButton != newViewProps.showFullscreenButton || needsLoadVideo) {
    [self.controlsLayer setShowFullscreenButton:newViewProps.showFullscreenButton];
  }

  // 9. Fullscreen prop update - ONLY if explicitly specified and changed by consumer in JS props
  if (oldViewPropsPtr && oldViewPropsPtr->fullscreen != newViewProps.fullscreen) {
    [self setFullscreenMode:newViewProps.fullscreen notifyJS:NO];
  }

  // 10. Auto adjust safe area prop update
  if (!oldViewPropsPtr || oldViewPropsPtr->autoAdjustSafeArea != newViewProps.autoAdjustSafeArea || needsLoadVideo) {
    [self setAutoAdjustSafeAreaMode:newViewProps.autoAdjustSafeArea];
  }

  // 11. Custom Icons JSON
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->icons != newViewProps.icons || needsLoadVideo)) {
    if (!newViewProps.icons.empty()) {
      NSString *iconsStr = [NSString stringWithUTF8String:newViewProps.icons.c_str()];
      [self.controlsLayer setIconsJSON:iconsStr];
    }
  }

  // 12. Colors (accent, track, buffer)
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->accentColor != newViewProps.accentColor || needsLoadVideo)) {
    if (!newViewProps.accentColor.empty()) {
      NSString *colorStr = [NSString stringWithUTF8String:newViewProps.accentColor.c_str()];
      [self.controlsLayer setAccentColorHex:colorStr];
    }
  }
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->trackColor != newViewProps.trackColor || needsLoadVideo)) {
    if (!newViewProps.trackColor.empty()) {
      NSString *colorStr = [NSString stringWithUTF8String:newViewProps.trackColor.c_str()];
      [self.controlsLayer setTrackColorHex:colorStr];
    }
  }
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->bufferColor != newViewProps.bufferColor || needsLoadVideo)) {
    if (!newViewProps.bufferColor.empty()) {
      NSString *colorStr = [NSString stringWithUTF8String:newViewProps.bufferColor.c_str()];
      [self.controlsLayer setBufferColorHex:colorStr];
    }
  }

  // 13. Skip interval & Button visibility
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->skipInterval != newViewProps.skipInterval || needsLoadVideo)) {
    [self.controlsLayer setSkipIntervalSeconds:newViewProps.skipInterval];
  }
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->showRewindButton != newViewProps.showRewindButton || needsLoadVideo)) {
    [self.controlsLayer setShowRewindButton:newViewProps.showRewindButton];
  }
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->showForwardButton != newViewProps.showForwardButton || needsLoadVideo)) {
    [self.controlsLayer setShowForwardButton:newViewProps.showForwardButton];
  }
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->showPlayPauseButton != newViewProps.showPlayPauseButton || needsLoadVideo)) {
    [self.controlsLayer setShowPlayPauseButton:newViewProps.showPlayPauseButton];
  }

  // 14. Auto-hide timeout & Controls visibility
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->autoHideTimeout != newViewProps.autoHideTimeout || needsLoadVideo)) {
    [self.controlsLayer setAutoHideTimeoutMs:newViewProps.autoHideTimeout];
  }
  if (self.controlsLayer && (!oldViewPropsPtr || oldViewPropsPtr->controls != newViewProps.controls || needsLoadVideo)) {
    [self.controlsLayer setControlsAllowed:newViewProps.controls];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)setAutoAdjustSafeAreaMode:(BOOL)autoAdjust {
  _autoAdjustSafeArea = autoAdjust;
  [self.controlsLayer setAutoAdjustSafeArea:autoAdjust];
  if (self.fullscreenContainerView) {
    self.fullscreenContainerView.autoAdjustSafeArea = autoAdjust;
    [self.fullscreenContainerView setNeedsLayout];
  }
  [self updateControlsConstraints];
  [self setNeedsLayout];
}

- (void)updateControlsConstraints {
  if (self.controlsConstraints.count > 0) {
    [NSLayoutConstraint deactivateConstraints:self.controlsConstraints];
  }
  if (!self.controlsLayer || self.controlsLayer.superview != self) {
    return;
  }
  self.controlsLayer.translatesAutoresizingMaskIntoConstraints = NO;
  if (self.autoAdjustSafeArea) {
    self.controlsConstraints = @[
      [self.controlsLayer.leadingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.leadingAnchor],
      [self.controlsLayer.trailingAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.trailingAnchor],
      [self.controlsLayer.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor],
      [self.controlsLayer.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor]
    ];
  } else {
    self.controlsConstraints = @[
      [self.controlsLayer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
      [self.controlsLayer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
      [self.controlsLayer.topAnchor constraintEqualToAnchor:self.topAnchor],
      [self.controlsLayer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ];
  }
  [NSLayoutConstraint activateConstraints:self.controlsConstraints];
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

  // Configure audio session for background playback and movie mode
  NSError *audioError = nil;
  AVAudioSession *session = [AVAudioSession sharedInstance];
  [session setCategory:AVAudioSessionCategoryPlayback
                  mode:AVAudioSessionModeMoviePlayback
               options:0
                 error:&audioError];
  if (audioError) {
    NSLog(@"[RCTVideoPlayer] Audio session category error: %@", audioError);
  }
  audioError = nil;
  [session setActive:YES error:&audioError];
  if (audioError) {
    NSLog(@"[RCTVideoPlayer] Audio session activation error: %@", audioError);
  }

  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVAudioSessionInterruptionNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVAudioSessionRouteChangeNotification
                                                object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleAudioInterruption:)
                                               name:AVAudioSessionInterruptionNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleAudioRouteChange:)
                                               name:AVAudioSessionRouteChangeNotification
                                             object:nil];

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

  // 3. Picture in Picture Controller Setup
  if ([AVPictureInPictureController isPictureInPictureSupported]) {
    _pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:self.playerLayer];
    _pipController.delegate = self;
  }

  // 4. Control Overlay Layer
  self.controlsLayer = [[ControlLayer alloc] initWithFrame:self.bounds];
  [self.controlsLayer setCoordinator:_coordinator.get()];
  [self.controlsLayer setVideoPlayer:self.player];
  [self.controlsLayer setAutoAdjustSafeArea:self.autoAdjustSafeArea];
  self.controlsLayer.layer.zPosition = 1;
  [self addSubview:self.controlsLayer];

  [self updateControlsConstraints];

  // 5. MediaSession / NowPlaying & Remote Commands Setup
  self.mediaSessionManager = [[MediaSessionManager alloc] init];
  self.mediaSessionManager.delegate = self;
  NSTimeInterval skipInterval = props.skipInterval > 0 ? props.skipInterval : 15.0;
  [self.mediaSessionManager setupRemoteCommandsWithSkipInterval:skipInterval];

  __weak RCTVideoPlayer *weakSelf = self;
  CMTime periodicInterval = CMTimeMake(1, 1);
  self.timeObserverToken = [self.player addPeriodicTimeObserverForInterval:periodicInterval
                                                                     queue:dispatch_get_main_queue()
                                                                usingBlock:^(CMTime time) {
    RCTVideoPlayer *strongSelf = weakSelf;
    if (!strongSelf || !strongSelf.player) return;
    NSTimeInterval currentTime = CMTimeGetSeconds(time);
    NSTimeInterval duration = CMTimeGetSeconds(strongSelf.player.currentItem.duration);
    float rate = strongSelf.player.rate;
    NSString *title = strongSelf.controlsLayer.title ?: @"";
    [strongSelf.mediaSessionManager updateNowPlayingInfoWithTitle:title
                                                     currentTime:currentTime
                                                        duration:isnan(duration) ? 0 : duration
                                                    playbackRate:rate];
  }];

  self.controlsLayer.onFullscreenToggleRequested = ^(BOOL isFullscreen) {
    [weakSelf setFullscreenMode:isFullscreen notifyJS:YES];
  };
  self.controlsLayer.onCaptionsToggleRequested = ^{
    [weakSelf.subtitleManager toggleSubtitles];
  };
  [self.subtitleManager attachPlayerItem:self.player.currentItem];

  self.adapter.onItemReadyToPlay = ^(AVPlayerItem *item) {
    RCTVideoPlayer *strongSelf = weakSelf;
    if (!strongSelf) return;
    [strongSelf.subtitleManager attachPlayerItem:item];
    const auto &currentProps = *std::static_pointer_cast<VideoPlayerProps const>(strongSelf->_props);
    NSString *propTitle = !currentProps.title.empty() ? [NSString stringWithUTF8String:currentProps.title.c_str()] : nil;
    MediaMetadataInfo *resolvedInfo = [strongSelf.metadataResolver resolveWithExplicitTitle:propTitle
                                                                                 playerItem:item
                                                                                        url:url];
    dispatch_async(dispatch_get_main_queue(), ^{
      [strongSelf.controlsLayer setTitle:resolvedInfo.title];
      NSTimeInterval duration = CMTimeGetSeconds(item.duration);
      [strongSelf.mediaSessionManager updateNowPlayingInfoWithTitle:resolvedInfo.title
                                                       currentTime:CMTimeGetSeconds(strongSelf.player.currentTime)
                                                          duration:isnan(duration) ? 0 : duration
                                                      playbackRate:strongSelf.player.rate];
    });
  };
  [self.controlsLayer setFullscreen:props.fullscreen];
  [self.controlsLayer setShowFullscreenButton:props.showFullscreenButton];

  if (!props.icons.empty()) {
    [self.controlsLayer setIconsJSON:[NSString stringWithUTF8String:props.icons.c_str()]];
  }
  if (!props.accentColor.empty()) {
    [self.controlsLayer setAccentColorHex:[NSString stringWithUTF8String:props.accentColor.c_str()]];
  }
  if (!props.trackColor.empty()) {
    [self.controlsLayer setTrackColorHex:[NSString stringWithUTF8String:props.trackColor.c_str()]];
  }
  if (!props.bufferColor.empty()) {
    [self.controlsLayer setBufferColorHex:[NSString stringWithUTF8String:props.bufferColor.c_str()]];
  }
  if (props.skipInterval > 0) {
    [self.controlsLayer setSkipIntervalSeconds:props.skipInterval];
  }
  [self.controlsLayer setShowRewindButton:props.showRewindButton];
  [self.controlsLayer setShowForwardButton:props.showForwardButton];
  [self.controlsLayer setShowPlayPauseButton:props.showPlayPauseButton];
  if (props.autoHideTimeout > 0) {
    [self.controlsLayer setAutoHideTimeoutMs:props.autoHideTimeout];
  }
  [self.controlsLayer setControlsAllowed:props.controls];

  // Auto-resolve title (explicit prop or URL slug fallback)
  NSString *explicitTitle = !props.title.empty() ? [NSString stringWithUTF8String:props.title.c_str()] : nil;
  MediaMetadataInfo *info = [self.metadataResolver resolveWithExplicitTitle:explicitTitle
                                                                 playerItem:self.player.currentItem
                                                                        url:url];
  [self.controlsLayer setTitle:info.title];

  // Asynchronously load thumbnail/frame
  [self.thumbnailProvider loadThumbnailForURL:url
                                  artworkData:info.artworkData
                                   completion:^(UIImage * _Nullable image) {}];
  if (props.play) {
    _coordinator->requestPlay();
  }

  [self emitResult:@"success"];
}

- (UIViewController *)findTopViewController {
  UIWindow *keyWindow = nil;
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
      UIWindowScene *windowScene = (UIWindowScene *)scene;
      for (UIWindow *w in windowScene.windows) {
        if (w.isKeyWindow) { keyWindow = w; break; }
      }
      if (keyWindow) break;
    }
  }
  if (!keyWindow) {
    keyWindow = self.window ?: [UIApplication sharedApplication].delegate.window;
  }
  UIViewController *top = keyWindow.rootViewController;
  while (top.presentedViewController) {
    top = top.presentedViewController;
  }
  return top;
}

- (void)setFullscreenMode:(BOOL)isFullscreen notifyJS:(BOOL)notifyJS {
  if (self.isFullscreenActive == isFullscreen || self.isFullscreenTransitioning) {
    return;
  }
  self.isFullscreenTransitioning = YES;
  [self.controlsLayer setFullscreen:isFullscreen];

  if (isFullscreen) {
    UIViewController *topVC = [self findTopViewController];
    if (!topVC) {
      self.isFullscreenTransitioning = NO;
      return;
    }

    self.isFullscreenActive = YES;
    [OrientationManager setSupportedInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];

    // 1. Create Fullscreen Container View pinned to topVC.view bounds
    FullscreenPlayerContainerView *container = [[FullscreenPlayerContainerView alloc] initWithFrame:topVC.view.bounds];
    container.backgroundColor = [UIColor blackColor];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    container.layer.zPosition = 9999;
    container.autoAdjustSafeArea = self.autoAdjustSafeArea;
    self.fullscreenContainerView = container;

    // 2. Reparent playerLayer and controlsLayer into fullscreen container
    [self.playerLayer removeFromSuperlayer];
    UIEdgeInsets fsInsets = self.autoAdjustSafeArea ? container.safeAreaInsets : UIEdgeInsetsZero;
    self.playerLayer.frame = UIEdgeInsetsInsetRect(container.bounds, fsInsets);
    container.playerLayer = self.playerLayer;
    [container.layer addSublayer:self.playerLayer];

    [self.controlsLayer removeFromSuperview];
    self.controlsLayer.frame = container.bounds;
    [container addSubview:self.controlsLayer];

    self.controlsLayer.translatesAutoresizingMaskIntoConstraints = NO;
    if (self.autoAdjustSafeArea) {
      [NSLayoutConstraint activateConstraints:@[
        [self.controlsLayer.leadingAnchor constraintEqualToAnchor:container.safeAreaLayoutGuide.leadingAnchor],
        [self.controlsLayer.trailingAnchor constraintEqualToAnchor:container.safeAreaLayoutGuide.trailingAnchor],
        [self.controlsLayer.topAnchor constraintEqualToAnchor:container.safeAreaLayoutGuide.topAnchor],
        [self.controlsLayer.bottomAnchor constraintEqualToAnchor:container.safeAreaLayoutGuide.bottomAnchor]
      ]];
    } else {
      [NSLayoutConstraint activateConstraints:@[
        [self.controlsLayer.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.controlsLayer.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [self.controlsLayer.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.controlsLayer.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
      ]];
    }

    [topVC.view addSubview:container];

    // 3. Request Landscape Orientation (Single OS window scene rotation)
    if (@available(iOS 16.0, *)) {
      [topVC setNeedsUpdateOfSupportedInterfaceOrientations];
      UIWindowScene *scene = (UIWindowScene *)topVC.view.window.windowScene ?: (UIWindowScene *)self.window.windowScene;
      if (scene) {
        UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
        [scene requestGeometryUpdateWithPreferences:preferences errorHandler:nil];
      }
    } else {
      [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationLandscapeRight) forKey:@"orientation"];
      [UIViewController attemptRotationToDeviceOrientation];
    }

    __weak RCTVideoPlayer *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      RCTVideoPlayer *strongSelf = weakSelf;
      if (strongSelf) {
        strongSelf.isFullscreenTransitioning = NO;
      }
    });
  } else {
    self.isFullscreenActive = NO;
    [OrientationManager setSupportedInterfaceOrientations:UIInterfaceOrientationMaskPortrait];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];

    UIViewController *topVC = [self findTopViewController];
    if (@available(iOS 16.0, *)) {
      if (topVC) {
        [topVC setNeedsUpdateOfSupportedInterfaceOrientations];
      }
      UIWindowScene *scene = (UIWindowScene *)topVC.view.window.windowScene ?: (UIWindowScene *)self.window.windowScene;
      if (scene) {
        UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskPortrait];
        [scene requestGeometryUpdateWithPreferences:preferences errorHandler:nil];
      }
    } else {
      [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationPortrait) forKey:@"orientation"];
      [UIViewController attemptRotationToDeviceOrientation];
    }

    __weak RCTVideoPlayer *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      RCTVideoPlayer *strongSelf = weakSelf;
      if (!strongSelf) return;

      if (strongSelf.fullscreenContainerView) {
        [strongSelf.playerLayer removeFromSuperlayer];
        UIEdgeInsets insets = strongSelf.autoAdjustSafeArea ? strongSelf.safeAreaInsets : UIEdgeInsetsZero;
        strongSelf.playerLayer.frame = UIEdgeInsetsInsetRect(strongSelf.bounds, insets);
        [strongSelf.layer addSublayer:strongSelf.playerLayer];

        [strongSelf.controlsLayer removeFromSuperview];
        strongSelf.controlsLayer.frame = strongSelf.bounds;
        [strongSelf addSubview:strongSelf.controlsLayer];

        [strongSelf updateControlsConstraints];

        [strongSelf.fullscreenContainerView removeFromSuperview];
        strongSelf.fullscreenContainerView = nil;
      }

      [strongSelf setNeedsLayout];
      [strongSelf layoutIfNeeded];
      strongSelf.isFullscreenTransitioning = NO;
    });
  }

  if (notifyJS && _eventEmitter) {
    auto videoPlayerEventEmitter = std::static_pointer_cast<VideoPlayerEventEmitter const>(_eventEmitter);
    VideoPlayerEventEmitter::OnFullscreenChange event;
    event.isFullscreen = isFullscreen;
    videoPlayerEventEmitter->onFullscreenChange(event);
  }
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

- (void)safeAreaInsetsDidChange {
  [super safeAreaInsetsDidChange];
  [self setNeedsLayout];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  if (!self.isFullscreenActive) {
    UIEdgeInsets insets = self.autoAdjustSafeArea ? self.safeAreaInsets : UIEdgeInsetsZero;
    CGRect safeBounds = UIEdgeInsetsInsetRect(self.bounds, insets);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.playerLayer.frame = safeBounds;
    [CATransaction commit];
  }
}

- (void)cleanup {
  if (self.isFullscreenActive) {
    [OrientationManager setSupportedInterfaceOrientations:UIInterfaceOrientationMaskPortrait];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    UIViewController *topVC = [self findTopViewController];
    if (@available(iOS 16.0, *)) {
      if (topVC) {
        [topVC setNeedsUpdateOfSupportedInterfaceOrientations];
        UIWindowScene *scene = (UIWindowScene *)topVC.view.window.windowScene ?: (UIWindowScene *)self.window.windowScene;
        if (scene) {
          UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:UIInterfaceOrientationMaskPortrait];
          [scene requestGeometryUpdateWithPreferences:preferences errorHandler:nil];
        }
      }
    } else {
      [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationPortrait) forKey:@"orientation"];
    }

    if (self.fullscreenContainerView) {
      [self.playerLayer removeFromSuperlayer];
      [self.controlsLayer removeFromSuperview];
      [self.fullscreenContainerView removeFromSuperview];
      self.fullscreenContainerView = nil;
    }
    self.isFullscreenActive = NO;
    self.isFullscreenTransitioning = NO;
  }

  // Remove audio session observers
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVAudioSessionInterruptionNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVAudioSessionRouteChangeNotification
                                                object:nil];

  // Clean up PiP controller
  if (_pipController) {
    _pipController.delegate = nil;
    _pipController = nil;
  }

  // Clean up time observer and MediaSession
  if (self.timeObserverToken && self.player) {
    [self.player removeTimeObserver:self.timeObserverToken];
    self.timeObserverToken = nil;
  }

  if (self.mediaSessionManager) {
    [self.mediaSessionManager cleanup];
    self.mediaSessionManager = nil;
  }

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
  [self.thumbnailProvider clearCache];
  [self.subtitleManager attachPlayerItem:nil];
  _coordinator = nullptr;
}

#pragma mark - Audio Session Notifications

- (void)handleAudioInterruption:(NSNotification *)notification {
  NSDictionary *userInfo = notification.userInfo;
  AVAudioSessionInterruptionType interruptionType = (AVAudioSessionInterruptionType)[userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
  if (interruptionType == AVAudioSessionInterruptionTypeBegan) {
    if (_coordinator) {
      _coordinator->requestPause();
    }
  } else if (interruptionType == AVAudioSessionInterruptionTypeEnded) {
    AVAudioSessionInterruptionOptions options = (AVAudioSessionInterruptionOptions)[userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
    if (options & AVAudioSessionInterruptionOptionShouldResume) {
      if (_coordinator) {
        _coordinator->requestPlay();
      }
    }
  }
}

- (void)handleAudioRouteChange:(NSNotification *)notification {
  NSDictionary *userInfo = notification.userInfo;
  AVAudioSessionRouteChangeReason reason = (AVAudioSessionRouteChangeReason)[userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
  if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
    if (_coordinator) {
      _coordinator->requestPause();
    }
  }
}

#pragma mark - MediaSessionManagerDelegate

- (void)mediaSessionDidRequestPlay {
  if (_coordinator) {
    _coordinator->requestPlay();
  }
}

- (void)mediaSessionDidRequestPause {
  if (_coordinator) {
    _coordinator->requestPause();
  }
}

- (void)mediaSessionDidRequestSeekTo:(NSTimeInterval)time {
  if (_coordinator) {
    _coordinator->requestSeek(time);
  }
}

- (void)mediaSessionDidRequestSkipForward:(NSTimeInterval)interval {
  if (_coordinator) {
    PlayerCore::PlayerSnapshot snapshot = _coordinator->getSnapshot();
    _coordinator->requestSeek(snapshot.currentTime + interval);
  }
}

- (void)mediaSessionDidRequestSkipBackward:(NSTimeInterval)interval {
  if (_coordinator) {
    PlayerCore::PlayerSnapshot snapshot = _coordinator->getSnapshot();
    _coordinator->requestSeek(std::max(0.0, snapshot.currentTime - interval));
  }
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
  if (self.controlsLayer) {
    [self.controlsLayer hideControlsAnimated:NO];
    [self.controlsLayer setControlsAllowed:NO];
  }
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
  if (self.controlsLayer) {
    const auto &currentProps = *std::static_pointer_cast<VideoPlayerProps const>(_props);
    [self.controlsLayer setControlsAllowed:currentProps.controls];
    [self.controlsLayer showControlsAnimated:YES];
  }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
  completionHandler(YES);
}

#pragma mark - SubtitleManagerDelegate

- (void)subtitleManager:(SubtitleManager *)manager
     didUpdateSubtitles:(NSArray<SubtitleTrack *> *)subtitles
         activeSubtitle:(nullable SubtitleTrack *)activeSubtitle {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.controlsLayer setCaptionsVisible:(subtitles.count > 0)];
    [self.controlsLayer setCaptionsActive:(activeSubtitle != nil)];
  });
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
