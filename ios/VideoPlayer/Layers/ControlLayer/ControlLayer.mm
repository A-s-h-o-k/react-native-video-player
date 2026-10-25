//
//  ControlLayer.mm
//  Player
//
//  Created by Ashok Ammineni on 25/12/25.
//

#import "ControlLayer.h"
#import "TopSection.h"
#import "BottomSection.h"

#pragma mark - C++ Observer Implementation

class ControlLayerObserverImpl : public PlayerCore::IPlayerStateObserver {
public:
    ControlLayerObserverImpl(__weak ControlLayer *layer) : layer_(layer) {}
    virtual ~ControlLayerObserverImpl() = default;

    void onStateChanged(PlayerCore::PlaybackState newState, PlayerCore::PlaybackState oldState) override {
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

    void onBufferUpdated(double bufferedTime, double percentage) override {}
    void onMuteChanged(bool isMuted, float volume) override {}
    void onPlaybackRateChanged(float rate) override {}
    void onError(int errorCode, const std::string& message) override {}

private:
    __weak ControlLayer *layer_;
};

#pragma mark - ControlLayer Implementation

@interface ControlLayer () {
    PlayerCore::PlayerStateCoordinator *_coordinator;
    std::shared_ptr<ControlLayerObserverImpl> _observer;
}
@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, strong, nullable) NSTimer *autoHideTimer;
@end


@implementation ControlLayer

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _playing = NO;
    _controlsVisible = YES;
    self.backgroundColor = UIColor.clearColor;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    [self setupUI:frame];
  }
  return self;
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

  // 2. Background Tap Gesture to Toggle Controls
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
  [self addGestureRecognizer:tap];
  self.userInteractionEnabled = YES;

  // 3. Top Section Slot (Pinned directly to the top edge)
  self.topControlView = [[TopSection alloc] initWithFrame:CGRectZero];
  self.topControlView.delegate = self;
  self.topControlView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.controlsContainerView addSubview:self.topControlView];
  [NSLayoutConstraint activateConstraints:@[
    [self.topControlView.leadingAnchor constraintEqualToAnchor:self.controlsContainerView.leadingAnchor],
    [self.topControlView.trailingAnchor constraintEqualToAnchor:self.controlsContainerView.trailingAnchor],
    [self.topControlView.topAnchor constraintEqualToAnchor:self.controlsContainerView.topAnchor]
  ]];

  // 4. Center Section Slot (Centered horizontally and vertically)
  self.centerControlView = [[CenterSection alloc] initWithFrame:CGRectZero];
  self.centerControlView.delegate = self;
  self.centerControlView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.controlsContainerView addSubview:self.centerControlView];
  [NSLayoutConstraint activateConstraints:@[
    [self.centerControlView.centerXAnchor constraintEqualToAnchor:self.controlsContainerView.centerXAnchor],
    [self.centerControlView.centerYAnchor constraintEqualToAnchor:self.controlsContainerView.centerYAnchor]
  ]];

  // 5. Bottom Section Slot (Pinned directly to the bottom edge)
  self.bottomControlView = [[BottomSection alloc] initWithFrame:CGRectZero];
  self.bottomControlView.delegate = self;
  self.bottomControlView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.controlsContainerView addSubview:self.bottomControlView];
  [NSLayoutConstraint activateConstraints:@[
    [self.bottomControlView.leadingAnchor constraintEqualToAnchor:self.controlsContainerView.leadingAnchor],
    [self.bottomControlView.trailingAnchor constraintEqualToAnchor:self.controlsContainerView.trailingAnchor],
    [self.bottomControlView.bottomAnchor constraintEqualToAnchor:self.controlsContainerView.bottomAnchor]
  ]];

  // 6. Buffering Spinner (Centered)
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
}

#pragma mark - TopSectionDelegate

- (void)topSectionDidTapBack:(TopSection *)section {
  [self resetAutoHideTimer];
}

- (void)topSectionDidTapCaptions:(TopSection *)section {
  [self invalidateAutoHideTimer];
}

- (void)topSectionDidTapSettings:(TopSection *)section {
  [self invalidateAutoHideTimer];
}

- (void)setTitle:(NSString *)title {
  [self.topControlView setTitle:title];
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

#pragma mark - Visibility & Auto-Hide Lifecycle

- (void)handleBackgroundTap:(UITapGestureRecognizer *)recognizer {
  if (self.controlsVisible) {
    [self hideControlsAnimated:YES];
  } else {
    [self showControlsAnimated:YES];
  }
}

- (void)showControlsAnimated:(BOOL)animated {
  [self invalidateAutoHideTimer];
  self.controlsVisible = YES;

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
  self.controlsVisible = NO;

  void (^hideBlock)(void) = ^{
    self.controlsContainerView.alpha = 0.0;
  };

  if (animated) {
    [UIView animateWithDuration:0.25 animations:hideBlock];
  } else {
    hideBlock();
  }
}

- (void)resetAutoHideTimer {
  [self invalidateAutoHideTimer];
  if (self.playing) {
    [self scheduleAutoHideControls];
  }
}

- (void)scheduleAutoHideControls {
  [self invalidateAutoHideTimer];
  self.autoHideTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
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

