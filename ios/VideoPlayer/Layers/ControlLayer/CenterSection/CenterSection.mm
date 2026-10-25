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

  // 1. Rewind Button (15s)
  self.backwardButton = [[CommonButton alloc] initWithSize:CommonButtonSizeMedium style:CommonButtonStyleTranslucentCircle];
  [self.backwardButton setSystemIcon:@"gobackward.15" pointSize:22 weight:UIImageSymbolWeightSemibold];
  [self.backwardButton configureAccessibilityWithLabel:@"Rewind 15 seconds" hint:@"Seeks backward by 15 seconds"];
  __weak CenterSection *weakSelf = self;
  self.backwardButton.onTap = ^(CommonButton * _Nonnull button) {
    CenterSection *strongSelf = weakSelf;
    if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(centerSection:didTapRewind:)]) {
      [strongSelf.delegate centerSection:strongSelf didTapRewind:15.0];
    }
  };

  // 2. Play / Pause Button (Large)
  self.playButton = [[CommonButton alloc] initWithSize:CommonButtonSizeLarge style:CommonButtonStyleTranslucentCircle];
  [self.playButton setSystemIcon:@"play.fill" pointSize:32 weight:UIImageSymbolWeightBold];
  [self.playButton configureAccessibilityWithLabel:@"Play" hint:@"Starts video playback"];
  self.playButton.onTap = ^(CommonButton * _Nonnull button) {
    CenterSection *strongSelf = weakSelf;
    if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(centerSectionDidTapPlayPause:)]) {
      [strongSelf.delegate centerSectionDidTapPlayPause:strongSelf];
    }
  };

  // 3. Fast Forward Button (15s)
  self.forwardButton = [[CommonButton alloc] initWithSize:CommonButtonSizeMedium style:CommonButtonStyleTranslucentCircle];
  [self.forwardButton setSystemIcon:@"goforward.15" pointSize:22 weight:UIImageSymbolWeightSemibold];
  [self.forwardButton configureAccessibilityWithLabel:@"Fast forward 15 seconds" hint:@"Seeks forward by 15 seconds"];
  self.forwardButton.onTap = ^(CommonButton * _Nonnull button) {
    CenterSection *strongSelf = weakSelf;
    if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(centerSection:didTapForward:)]) {
      [strongSelf.delegate centerSection:strongSelf didTapForward:15.0];
    }
  };

  [self addArrangedSubview:self.backwardButton];
  [self addArrangedSubview:self.playButton];
  [self addArrangedSubview:self.forwardButton];
}

- (void)setPlaying:(BOOL)playing isEnded:(BOOL)ended {
  _isPlayingState = playing;
  _isEndedState = ended;
  if (ended) {
    [self.playButton setSystemIcon:@"arrow.counterclockwise" pointSize:30 weight:UIImageSymbolWeightBold];
    [self.playButton configureAccessibilityWithLabel:@"Replay" hint:@"Replays video from the beginning"];
  } else if (playing) {
    [self.playButton setSystemIcon:@"pause.fill" pointSize:32 weight:UIImageSymbolWeightBold];
    [self.playButton configureAccessibilityWithLabel:@"Pause" hint:@"Pauses video playback"];
  } else {
    [self.playButton setSystemIcon:@"play.fill" pointSize:32 weight:UIImageSymbolWeightBold];
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
