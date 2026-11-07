//
//  CenterSection.mm
//  Player
//
//  Created by Ashok Ammineni on 05/02/26.
//

#import "CenterSection.h"

@interface CenterSection ()
@property (nonatomic, assign) BOOL isPlayingState;
@property (nonatomic, assign) BOOL isEndedState;
@end

@implementation CenterSection

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _skipInterval = 15.0;
    _isPlayingState = NO;
    _isEndedState = NO;
    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  self.axis = UILayoutConstraintAxisHorizontal;
  self.alignment = UIStackViewAlignmentCenter;
  self.distribution = UIStackViewDistributionEqualCentering;
  self.spacing = 24.0;
  self.translatesAutoresizingMaskIntoConstraints = NO;

  // 1. Rewind Button
  self.backwardButton = [[CommonButton alloc] initWithSize:CommonButtonSizeMedium style:CommonButtonStyleTranslucentCircle];
  [self updateRewindButtonIcon];
  __weak CenterSection *weakSelf = self;
  self.backwardButton.onTap = ^(CommonButton * _Nonnull button) {
    CenterSection *strongSelf = weakSelf;
    if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(centerSection:didTapRewind:)]) {
      [strongSelf.delegate centerSection:strongSelf didTapRewind:strongSelf.skipInterval];
    }
  };

  // 2. Play / Pause Button (Large)
  self.playButton = [[CommonButton alloc] initWithSize:CommonButtonSizeLarge style:CommonButtonStyleTranslucentCircle];
  [self.playButton setIconSource:self.customIcons[@"play"] fallbackSystemIcon:@"play.fill" pointSize:32 weight:UIImageSymbolWeightBold];
  [self.playButton configureAccessibilityWithLabel:@"Play" hint:@"Starts video playback"];
  self.playButton.onTap = ^(CommonButton * _Nonnull button) {
    CenterSection *strongSelf = weakSelf;
    if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(centerSectionDidTapPlayPause:)]) {
      [strongSelf.delegate centerSectionDidTapPlayPause:strongSelf];
    }
  };

  // 3. Fast Forward Button
  self.forwardButton = [[CommonButton alloc] initWithSize:CommonButtonSizeMedium style:CommonButtonStyleTranslucentCircle];
  [self updateForwardButtonIcon];
  self.forwardButton.onTap = ^(CommonButton * _Nonnull button) {
    CenterSection *strongSelf = weakSelf;
    if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(centerSection:didTapForward:)]) {
      [strongSelf.delegate centerSection:strongSelf didTapForward:strongSelf.skipInterval];
    }
  };

  [self addArrangedSubview:self.backwardButton];
  [self addArrangedSubview:self.playButton];
  [self addArrangedSubview:self.forwardButton];
}

- (void)setSkipInterval:(NSTimeInterval)skipInterval {
  _skipInterval = (skipInterval > 0) ? skipInterval : 15.0;
  [self updateRewindButtonIcon];
  [self updateForwardButtonIcon];
}

- (void)updateRewindButtonIcon {
  NSString *fallback = @"gobackward.15";
  if ((NSInteger)self.skipInterval == 10) fallback = @"gobackward.10";
  else if ((NSInteger)self.skipInterval == 30) fallback = @"gobackward.30";
  else if ((NSInteger)self.skipInterval == 5) fallback = @"gobackward.5";
  else if ((NSInteger)self.skipInterval != 15) fallback = @"gobackward";

  [self.backwardButton setIconSource:self.customIcons[@"rewind"] fallbackSystemIcon:fallback pointSize:22 weight:UIImageSymbolWeightSemibold];
  [self.backwardButton configureAccessibilityWithLabel:[NSString stringWithFormat:@"Rewind %d seconds", (int)self.skipInterval] hint:@"Seeks backward"];
}

- (void)updateForwardButtonIcon {
  NSString *fallback = @"goforward.15";
  if ((NSInteger)self.skipInterval == 10) fallback = @"goforward.10";
  else if ((NSInteger)self.skipInterval == 30) fallback = @"goforward.30";
  else if ((NSInteger)self.skipInterval == 5) fallback = @"goforward.5";
  else if ((NSInteger)self.skipInterval != 15) fallback = @"goforward";

  [self.forwardButton setIconSource:self.customIcons[@"forward"] fallbackSystemIcon:fallback pointSize:22 weight:UIImageSymbolWeightSemibold];
  [self.forwardButton configureAccessibilityWithLabel:[NSString stringWithFormat:@"Fast forward %d seconds", (int)self.skipInterval] hint:@"Seeks forward"];
}

- (void)setCustomIcons:(NSDictionary<NSString *,NSString *> *)customIcons {
  _customIcons = [customIcons copy];
  [self updateRewindButtonIcon];
  [self updateForwardButtonIcon];
  [self setPlaying:_isPlayingState isEnded:_isEndedState];
}

- (void)setShowRewindButton:(BOOL)show {
  self.backwardButton.hidden = !show;
}

- (void)setShowForwardButton:(BOOL)show {
  self.forwardButton.hidden = !show;
}

- (void)setShowPlayPauseButton:(BOOL)show {
  self.playButton.hidden = !show;
}

- (void)setPlaying:(BOOL)playing isEnded:(BOOL)ended {
  _isPlayingState = playing;
  _isEndedState = ended;
  if (ended) {
    [self.playButton setIconSource:self.customIcons[@"replay"] fallbackSystemIcon:@"arrow.counterclockwise" pointSize:30 weight:UIImageSymbolWeightBold];
    [self.playButton configureAccessibilityWithLabel:@"Replay" hint:@"Replays video from the beginning"];
  } else if (playing) {
    [self.playButton setIconSource:self.customIcons[@"pause"] fallbackSystemIcon:@"pause.fill" pointSize:32 weight:UIImageSymbolWeightBold];
    [self.playButton configureAccessibilityWithLabel:@"Pause" hint:@"Pauses video playback"];
  } else {
    [self.playButton setIconSource:self.customIcons[@"play"] fallbackSystemIcon:@"play.fill" pointSize:32 weight:UIImageSymbolWeightBold];
    [self.playButton configureAccessibilityWithLabel:@"Play" hint:@"Resumes video playback"];
  }
}

- (void)setPlaying:(BOOL)playing {
  [self setPlaying:playing isEnded:NO];
}

- (void)setPlaybackEnded:(BOOL)ended {
  [self setPlaying:NO isEnded:ended];
}

@end
