//
//  ControlLayer.mm
//  Player
//
//  Created by Ashok Ammineni on 25/12/25.
//

#import "ControlLayer.h"
#import "TopSection.h"
#import "BottomSection.h"
#import "../../Generated/PlayerThemeGenerated.h"

#pragma mark - C++ Observer Implementation

class ControlLayerObserverImpl : public PlayerCore::IPlayerStateObserver {
public:
    ControlLayerObserverImpl(__weak ControlLayer *layer) : layer_(layer) {}
    virtual ~ControlLayerObserverImpl() = default;

    void onStateChanged(PlayerCore::PlaybackState newState, PlayerCore::PlaybackState /*oldState*/) override {
        dispatch_async(dispatch_get_main_queue(), ^{
            ControlLayer *l = layer_;
            if (!l) return;
            BOOL isPlaying = (newState == PlayerCore::PlaybackState::Playing);
            BOOL isEnded = (newState == PlayerCore::PlaybackState::Ended);
            l.playing = isPlaying;
            [l.centerControlView setPlaying:isPlaying isEnded:isEnded];

            if (newState == PlayerCore::PlaybackState::Buffering) {
                [l.bufferingSpinner startAnimating];
            } else {
                [l.bufferingSpinner stopAnimating];
            }

            if (isPlaying) {
                [l resetAutoHideTimer];
            } else {
                [l showControlsAnimated:YES];
            }
        });
    }

    void onTimeUpdated(double currentTime, double duration) override {
        dispatch_async(dispatch_get_main_queue(), ^{
            ControlLayer *l = layer_;
            if (!l) return;
            [l.bottomControlView updateCurrentTime:currentTime duration:duration];
        });
    }

    void onBufferUpdated(double bufferedTime, double percentage) override {
        dispatch_async(dispatch_get_main_queue(), ^{
            ControlLayer *l = layer_;
            if (!l) return;
            [l.bottomControlView updateBufferTime:bufferedTime percentage:percentage];
        });
    }
    void onMuteChanged(bool /*isMuted*/, float /*volume*/) override {}
    void onPlaybackRateChanged(float /*rate*/) override {}
    void onError(int /*errorCode*/, const std::string& /*message*/) override {}

private:
    __weak ControlLayer *layer_;
};

#pragma mark - ControlLayer Implementation

static UIColor *ColorFromHexString(NSString *hexString) {
  if (!hexString || hexString.length == 0) return nil;
  NSString *clean = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@""];
  unsigned int rgbValue = 0;
  NSScanner *scanner = [NSScanner scannerWithString:clean];
  [scanner scanHexInt:&rgbValue];
  if (clean.length == 6) {
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0
                           green:((rgbValue & 0x00FF00) >> 8)/255.0
                            blue:(rgbValue & 0x0000FF)/255.0
                           alpha:1.0];
  } else if (clean.length == 8) {
    return [UIColor colorWithRed:((rgbValue & 0xFF000000) >> 24)/255.0
                           green:((rgbValue & 0x00FF0000) >> 16)/255.0
                            blue:((rgbValue & 0x0000FF00) >> 8)/255.0
                           alpha:((rgbValue & 0x000000FF))/255.0];
  }
  return nil;
}

@interface ControlLayer () {
    PlayerCore::PlayerStateCoordinator *_coordinator;
    std::shared_ptr<ControlLayerObserverImpl> _observer;
    NSInteger _autoHideTimeoutMs;
    BOOL _controlsAllowed;
    BOOL _controlsVisible;
    NSString *_title;
}
@property (nonatomic, strong, nullable) NSTimer *autoHideTimer;
@property (nonatomic, assign, readwrite) BOOL isFullscreen;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *topSectionConstraints;
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *bottomSectionConstraints;
@end


@implementation ControlLayer

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _playing = NO;
    _controlsVisible = YES;
    _autoHideTimeoutMs = 5000;
    _controlsAllowed = YES;
    _isFullscreen = NO;
    _autoAdjustSafeArea = YES;
    self.backgroundColor = UIColor.clearColor;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self setupUI:frame];
    [self applyAotGeneratedTheme];
  }
  return self;
}

- (void)applyAotGeneratedTheme {
  _autoHideTimeoutMs = THEME_GEN_AUTO_HIDE_TIMEOUT;
  [self setAccentColorHex:THEME_GEN_ACCENT_COLOR];
  [self setTrackColorHex:THEME_GEN_TRACK_COLOR];
  [self setBufferColorHex:THEME_GEN_BUFFER_COLOR];
  [self setSkipIntervalSeconds:THEME_GEN_SKIP_INTERVAL];
  [self setShowRewindButton:THEME_GEN_SHOW_REWIND_BUTTON];
  [self setShowForwardButton:THEME_GEN_SHOW_FORWARD_BUTTON];
  [self setShowPlayPauseButton:THEME_GEN_SHOW_PLAY_PAUSE_BUTTON];
  [self setShowFullscreenButton:THEME_GEN_SHOW_FULLSCREEN_BUTTON];

  NSMutableDictionary<NSString *, NSString *> *aotIcons = [NSMutableDictionary dictionary];
  if (THEME_GEN_ICON_PLAY.length > 0) aotIcons[@"play"] = THEME_GEN_ICON_PLAY;
  if (THEME_GEN_ICON_PAUSE.length > 0) aotIcons[@"pause"] = THEME_GEN_ICON_PAUSE;
  if (THEME_GEN_ICON_REPLAY.length > 0) aotIcons[@"replay"] = THEME_GEN_ICON_REPLAY;
  if (THEME_GEN_ICON_REWIND.length > 0) aotIcons[@"rewind"] = THEME_GEN_ICON_REWIND;
  if (THEME_GEN_ICON_FORWARD.length > 0) aotIcons[@"forward"] = THEME_GEN_ICON_FORWARD;
  if (THEME_GEN_ICON_FULLSCREEN_ENTER.length > 0) aotIcons[@"fullscreenEnter"] = THEME_GEN_ICON_FULLSCREEN_ENTER;
  if (THEME_GEN_ICON_FULLSCREEN_EXIT.length > 0) aotIcons[@"fullscreenExit"] = THEME_GEN_ICON_FULLSCREEN_EXIT;
  if (THEME_GEN_ICON_SLIDER_THUMB.length > 0) aotIcons[@"sliderThumb"] = THEME_GEN_ICON_SLIDER_THUMB;

  if (aotIcons.count > 0) {
    [self.centerControlView setCustomIcons:aotIcons];
    [self.bottomControlView setCustomIcons:aotIcons];
  }
}

- (void)setupUI:(CGRect)frame {
  // 1. Master Controls Container View (fades in/out during auto-hide)
  self.controlsContainerView = [[UIView alloc] init];
  self.controlsContainerView.translatesAutoresizingMaskIntoConstraints = NO;
  self.controlsContainerView.backgroundColor = UIColor.clearColor;
  self.controlsContainerView.alpha = 1.0;
  [self addSubview:self.controlsContainerView];
  self.stackView = self.controlsContainerView;

  [NSLayoutConstraint activateConstraints:@[
    [self.controlsContainerView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
    [self.controlsContainerView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    [self.controlsContainerView.topAnchor constraintEqualToAnchor:self.topAnchor],
    [self.controlsContainerView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
  ]];

  // 1b. Contrast Gradient Scrims (Top & Bottom)
  self.topGradientLayer = [CAGradientLayer layer];
  self.topGradientLayer.colors = @[
    (id)[UIColor colorWithWhite:0.0 alpha:0.65].CGColor,
    (id)[UIColor clearColor].CGColor
  ];
  [self.controlsContainerView.layer insertSublayer:self.topGradientLayer atIndex:0];

  self.bottomGradientLayer = [CAGradientLayer layer];
  self.bottomGradientLayer.colors = @[
    (id)[UIColor clearColor].CGColor,
    (id)[UIColor colorWithWhite:0.0 alpha:0.75].CGColor
  ];
  [self.controlsContainerView.layer insertSublayer:self.bottomGradientLayer atIndex:1];

  // 2. Background Tap Gesture to Toggle Controls
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
  tap.cancelsTouchesInView = NO;
  tap.delegate = self;
  [self addGestureRecognizer:tap];
  self.userInteractionEnabled = YES;

  // 3. Top Section Slot
  self.topControlView = [[TopSection alloc] initWithFrame:CGRectZero];
  self.topControlView.delegate = self;
  self.topControlView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.controlsContainerView addSubview:self.topControlView];

  // 4. Center Section Slot (Centered horizontally and vertically)
  self.centerControlView = [[CenterSection alloc] initWithFrame:CGRectZero];
  self.centerControlView.delegate = self;
  self.centerControlView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.controlsContainerView addSubview:self.centerControlView];
  [NSLayoutConstraint activateConstraints:@[
    [self.centerControlView.centerXAnchor constraintEqualToAnchor:self.controlsContainerView.centerXAnchor],
    [self.centerControlView.centerYAnchor constraintEqualToAnchor:self.controlsContainerView.centerYAnchor]
  ]];

  // 5. Bottom Section Slot
  self.bottomControlView = [[BottomSection alloc] initWithFrame:CGRectZero];
  self.bottomControlView.delegate = self;
  self.bottomControlView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.controlsContainerView addSubview:self.bottomControlView];

  // 6. Activate dynamic top & bottom constraints based on autoAdjustSafeArea
  [self updateSectionConstraints];

  // 7. Buffering Spinner (Centered)
  self.bufferingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  self.bufferingSpinner.color = UIColor.whiteColor;
  self.bufferingSpinner.hidesWhenStopped = YES;
  self.bufferingSpinner.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.bufferingSpinner];
  [NSLayoutConstraint activateConstraints:@[
    [self.bufferingSpinner.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
    [self.bufferingSpinner.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
  ]];
}

- (void)updateSectionConstraints {
  if (self.topSectionConstraints.count > 0) {
    [NSLayoutConstraint deactivateConstraints:self.topSectionConstraints];
  }
  if (self.bottomSectionConstraints.count > 0) {
    [NSLayoutConstraint deactivateConstraints:self.bottomSectionConstraints];
  }

  if (self.autoAdjustSafeArea) {
    self.topSectionConstraints = @[
      [self.topControlView.leadingAnchor constraintEqualToAnchor:self.controlsContainerView.safeAreaLayoutGuide.leadingAnchor],
      [self.topControlView.trailingAnchor constraintEqualToAnchor:self.controlsContainerView.safeAreaLayoutGuide.trailingAnchor],
      [self.topControlView.topAnchor constraintEqualToAnchor:self.controlsContainerView.safeAreaLayoutGuide.topAnchor constant:4.0]
    ];
    self.bottomSectionConstraints = @[
      [self.bottomControlView.leadingAnchor constraintEqualToAnchor:self.controlsContainerView.safeAreaLayoutGuide.leadingAnchor],
      [self.bottomControlView.trailingAnchor constraintEqualToAnchor:self.controlsContainerView.safeAreaLayoutGuide.trailingAnchor],
      [self.bottomControlView.bottomAnchor constraintEqualToAnchor:self.controlsContainerView.safeAreaLayoutGuide.bottomAnchor constant:-4.0]
    ];
  } else {
    self.topSectionConstraints = @[
      [self.topControlView.leadingAnchor constraintEqualToAnchor:self.controlsContainerView.leadingAnchor],
      [self.topControlView.trailingAnchor constraintEqualToAnchor:self.controlsContainerView.trailingAnchor],
      [self.topControlView.topAnchor constraintEqualToAnchor:self.controlsContainerView.topAnchor constant:4.0]
    ];
    self.bottomSectionConstraints = @[
      [self.bottomControlView.leadingAnchor constraintEqualToAnchor:self.controlsContainerView.leadingAnchor],
      [self.bottomControlView.trailingAnchor constraintEqualToAnchor:self.controlsContainerView.trailingAnchor],
      [self.bottomControlView.bottomAnchor constraintEqualToAnchor:self.controlsContainerView.bottomAnchor constant:-4.0]
    ];
  }

  [NSLayoutConstraint activateConstraints:self.topSectionConstraints];
  [NSLayoutConstraint activateConstraints:self.bottomSectionConstraints];
}

- (void)setAutoAdjustSafeArea:(BOOL)autoAdjust {
  if (_autoAdjustSafeArea == autoAdjust) {
    return;
  }
  _autoAdjustSafeArea = autoAdjust;
  [self updateSectionConstraints];
  [self setNeedsLayout];
}

#pragma mark - Coordinator & Player Binding

- (void)setCoordinator:(PlayerCore::PlayerStateCoordinator *)coordinator {
  if (_coordinator == coordinator && _observer) {
    return;
  }
  if (_coordinator && _observer) {
    _coordinator->removeObserver(_observer);
  }

  _observer = nullptr;
  _coordinator = coordinator;

  if (_coordinator) {
    _observer = std::make_shared<ControlLayerObserverImpl>(self);
    _coordinator->addObserver(_observer);
  }
}


- (void)setVideoPlayer:(AVPlayer *)player {
  self.player = player;
  self.playing = NO;
  [self.centerControlView setPlaying:NO];
  [player pause];
}

#pragma mark - CenterSectionDelegate

- (void)centerSectionDidTapPlayPause:(CenterSection *)section {
  [self resetAutoHideTimer];
  if (_coordinator) {
    _coordinator->requestTogglePlayPause();
  } else {
    [self togglePlayPauseFallback];
  }
}

- (void)centerSection:(CenterSection *)section didTapRewind:(NSTimeInterval)seconds {
  [self resetAutoHideTimer];
  if (_coordinator) {
    _coordinator->requestStepSeek(-seconds);
  } else {
    [self seekFallbackBy:-seconds];
  }
}

- (void)centerSection:(CenterSection *)section didTapForward:(NSTimeInterval)seconds {
  [self resetAutoHideTimer];
  if (_coordinator) {
    _coordinator->requestStepSeek(seconds);
  } else {
    [self seekFallbackBy:seconds];
  }
}

#pragma mark - BottomSectionDelegate

- (void)bottomSectionDidStartScrubbing:(BottomSection *)section {
  [self invalidateAutoHideTimer];
  if (_coordinator) {
    _coordinator->startScrubbing();
  }
}

- (void)bottomSection:(BottomSection *)section didScrubToTime:(NSTimeInterval)time {
  if (_coordinator) {
    _coordinator->scrubTo(time);
  }
}

- (void)bottomSection:(BottomSection *)section didEndScrubbing:(NSTimeInterval)time {
  if (_coordinator) {
    _coordinator->endScrubbing(time);
  } else if (self.player) {
    CMTime targetTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
    [self.player seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
  }

  if (self.playing) {
    [self resetAutoHideTimer];
  }
}

- (void)bottomSectionDidTapFullscreen:(BottomSection *)section {
  [self resetAutoHideTimer];
  BOOL target = !self.isFullscreen;
  if (self.onFullscreenToggleRequested) {
    self.onFullscreenToggleRequested(target);
  }
}

- (void)setFullscreen:(BOOL)isFullscreen {
  _isFullscreen = isFullscreen;
  [self.bottomControlView setFullscreen:isFullscreen];
}

- (void)setShowFullscreenButton:(BOOL)show {
  [self.bottomControlView setShowFullscreenButton:show];
}

#pragma mark - TopSectionDelegate

- (void)topSectionDidTapBack:(TopSection *)section {
  [self resetAutoHideTimer];
  if (self.isFullscreen && self.onFullscreenToggleRequested) {
    self.onFullscreenToggleRequested(NO);
  }
}

- (void)topSectionDidTapCaptions:(TopSection *)section {
  [self invalidateAutoHideTimer];
  if (self.onCaptionsToggleRequested) {
    self.onCaptionsToggleRequested();
  }
}

- (void)topSectionDidTapSettings:(TopSection *)section {
  [self invalidateAutoHideTimer];
}

- (void)setTitle:(NSString *)title {
  _title = [title copy];
  [self.topControlView setTitle:title];
}

- (nullable NSString *)title {
  return _title ?: self.topControlView.titleLabel.text;
}

- (void)setCaptionsVisible:(BOOL)visible {
  [self.topControlView setCaptionsVisible:visible];
}

- (void)setCaptionsActive:(BOOL)active {
  [self.topControlView setCaptionsActive:active];
}

- (void)togglePlayPauseFallback {
  if (!self.player) { return; }

  if (self.playing) {
    [self.player pause];
    self.playing = NO;
    [self.centerControlView setPlaying:NO isEnded:NO];
    [self invalidateAutoHideTimer];
  } else {
    if (self.player.currentItem && CMTIME_COMPARE_INLINE(self.player.currentTime, >=, self.player.currentItem.duration)) {
      [self.player seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    }
    [self.player play];
    self.playing = YES;
    [self.centerControlView setPlaying:YES isEnded:NO];
    [self scheduleAutoHideControls];
  }
}

- (void)seekFallbackBy:(NSTimeInterval)deltaSeconds {
  if (!self.player) { return; }
  NSTimeInterval current = CMTimeGetSeconds(self.player.currentTime);
  NSTimeInterval target = MAX(current + deltaSeconds, 0.0);
  CMTime targetTime = CMTimeMakeWithSeconds(target, NSEC_PER_SEC);
  [self.player seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGFloat width = self.bounds.size.width;
  CGFloat height = self.bounds.size.height;
  CGFloat topInset = self.autoAdjustSafeArea ? self.safeAreaInsets.top : 0.0;
  CGFloat bottomInset = self.autoAdjustSafeArea ? self.safeAreaInsets.bottom : 0.0;
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  self.topGradientLayer.frame = CGRectMake(0, 0, width, MIN(height * 0.45, MAX(90.0, topInset + 54.0)));
  self.bottomGradientLayer.frame = CGRectMake(0, MAX(0, height - MAX(100.0, bottomInset + 54.0)), width, MAX(100.0, bottomInset + 54.0));
  [CATransaction commit];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
  if ([touch.view isKindOfClass:[UIControl class]] ||
      [touch.view isKindOfClass:[UIButton class]] ||
      [touch.view isKindOfClass:[UISlider class]]) {
    return NO;
  }
  return YES;
}

#pragma mark - Visibility & Auto-Hide Lifecycle

- (BOOL)controlsVisible {
  return _controlsVisible;
}

- (BOOL)isControlsVisible {
  return _controlsVisible;
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer {
  if (!_controlsAllowed) return;
  if (_controlsVisible) {
    [self hideControlsAnimated:YES];
  } else {
    [self showControlsAnimated:YES];
  }
}

- (void)showControlsAnimated:(BOOL)animated {
  if (!_controlsAllowed) return;
  [self invalidateAutoHideTimer];
  _controlsVisible = YES;
  self.controlsContainerView.hidden = NO;

  void (^showBlock)(void) = ^{
    self.controlsContainerView.alpha = 1.0;
  };

  if (animated) {
    [UIView animateWithDuration:0.25 animations:showBlock];
  } else {
    showBlock();
  }

  if (self.playing) {
    [self scheduleAutoHideControls];
  }
}

- (void)hideControlsAnimated:(BOOL)animated {
  [self invalidateAutoHideTimer];
  _controlsVisible = NO;

  void (^hideBlock)(void) = ^{
    self.controlsContainerView.alpha = 0.0;
  };

  if (animated) {
    [UIView animateWithDuration:0.25 animations:hideBlock completion:^(__unused BOOL finished) {
      if (!self->_controlsVisible) {
        self.controlsContainerView.hidden = YES;
      }
    }];
  } else {
    hideBlock();
    self.controlsContainerView.hidden = YES;
  }
}

- (void)resetAutoHideTimer {
  [self invalidateAutoHideTimer];
  if (self.playing) {
    [self scheduleAutoHideControls];
  }
}

- (void)setIconsJSON:(nullable NSString *)iconsJSON {
  if (!iconsJSON || iconsJSON.length == 0) return;
  NSData *data = [iconsJSON dataUsingEncoding:NSUTF8StringEncoding];
  if (!data) return;
  NSError *err = nil;
  NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
  if ([dict isKindOfClass:[NSDictionary class]]) {
    [self.centerControlView setCustomIcons:dict];
    [self.bottomControlView setCustomIcons:dict];
    if (dict[@"back"]) {
      [self.topControlView.backButton setIconSource:dict[@"back"] fallbackSystemIcon:@"chevron.backward" pointSize:16 weight:UIImageSymbolWeightSemibold];
    }
  }
}

- (void)setAccentColorHex:(nullable NSString *)colorHex {
  UIColor *c = ColorFromHexString(colorHex);
  if (c) {
    [self.bottomControlView setAccentColor:c];
  }
}

- (void)setTrackColorHex:(nullable NSString *)colorHex {
  UIColor *c = ColorFromHexString(colorHex);
  if (c) {
    [self.bottomControlView setTrackColor:c];
  }
}

- (void)setBufferColorHex:(nullable NSString *)colorHex {
  UIColor *c = ColorFromHexString(colorHex);
  if (c) {
    [self.bottomControlView setBufferColor:c];
  }
}

- (void)setSkipIntervalSeconds:(NSInteger)seconds {
  if (seconds > 0) {
    [self.centerControlView setSkipInterval:seconds];
  }
}

- (void)setShowRewindButton:(BOOL)show {
  [self.centerControlView setShowRewindButton:show];
}

- (void)setShowForwardButton:(BOOL)show {
  [self.centerControlView setShowForwardButton:show];
}

- (void)setShowPlayPauseButton:(BOOL)show {
  [self.centerControlView setShowPlayPauseButton:show];
}

- (void)setAutoHideTimeoutMs:(NSInteger)timeoutMs {
  _autoHideTimeoutMs = timeoutMs;
  [self resetAutoHideTimer];
}

- (void)setControlsAllowed:(BOOL)allowed {
  _controlsAllowed = allowed;
  if (!allowed) {
    [self invalidateAutoHideTimer];
    _controlsVisible = NO;
    self.controlsContainerView.alpha = 0.0;
    self.controlsContainerView.hidden = YES;
    self.hidden = YES;
  } else {
    self.hidden = NO;
    self.userInteractionEnabled = YES;
    [self showControlsAnimated:NO];
  }
}

- (void)setControlsVisible:(BOOL)visible {
  [self setControlsAllowed:visible];
}

- (void)scheduleAutoHideControls {
  [self invalidateAutoHideTimer];
  if (_autoHideTimeoutMs <= 0) {
    return; // 0 = keep visible indefinitely
  }
  NSTimeInterval interval = _autoHideTimeoutMs / 1000.0;
  self.autoHideTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(autoHideTimerFired:)
                                                      userInfo:nil
                                                       repeats:NO];
}

- (void)invalidateAutoHideTimer {
  if (self.autoHideTimer) {
    [self.autoHideTimer invalidate];
    self.autoHideTimer = nil;
  }
}

- (void)autoHideTimerFired:(NSTimer *)timer {
  if (self.playing) {
    [self hideControlsAnimated:YES];
  }
}

- (void)dealloc {
  [self invalidateAutoHideTimer];
  if (_coordinator && _observer) {
    _coordinator->removeObserver(_observer);
  }
  _observer = nullptr;
  _coordinator = nullptr;
}

@end

