// ControlLayer.mm
#import "ControlLayer.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "TopSection.h"
#import "CenterSection.h"
#import "BottomSection.h"

@implementation ControlLayer

UIImage *playImage1 = [UIImage systemImageNamed:@"play.fill"];
UIImage *pauseImage1 = [UIImage systemImageNamed:@"pause.fill"];
NSTimer *_controlsAutoHideTimer;
BOOL _controlsVisible;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setupUI:frame];
    }
    self.playing = NO;
    self.backgroundColor = UIColor.clearColor;
    _controlsVisible = YES;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    return self;
}

-(void) setVideoPlayer:(AVPlayer *)player {
  self.player = player;
  NSLog(@"called initializing %@", self.player);
  self.playing = NO;
  [player pause];
}

-(void) onPausePressed {
  NSLog(@"Pause Button Pressed");
  [self showControlsAnimated:YES];
  NSLog(@"Player score: %d", self.playing);
  if(self.playing) {
    [self.player pause];
    self.playing = NO;
//    [self.playButton setImage:playImage1 forState:UIControlStateNormal];
  } else {
    [self.player play];
    self.playing = YES;
//    [self.playButton setImage:pauseImage1 forState:UIControlStateNormal];
  }
}
- (void)setupUI: (CGRect) frame {
    
    // control layer main stack view
    self.stackView = [[UIStackView alloc] init];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisVertical; // or Vertical depending on your design
    self.stackView.alignment = UIStackViewAlignmentCenter;  // centers inner content vertically for horizontal axis
    self.stackView.distribution = UIStackViewDistributionEqualCentering;
    self.stackView.spacing = 0;
    self.stackView.backgroundColor = UIColor.clearColor;

    [self addSubview:self.stackView];
    [NSLayoutConstraint activateConstraints:@[
        [self.stackView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.stackView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [self.stackView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
    ]];
    self.stackView.alpha = 1.0;
    [self setUserInteractionEnabled:YES];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleControlsTap:)];
    [self addGestureRecognizer:tap];
    self.userInteractionEnabled = YES;

    // Inner stack specifically for buttons
    self.topControlView = [[TopSection alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 40)];
  

    self.topControlView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.stackView addArrangedSubview:self.topControlView];
  [NSLayoutConstraint activateConstraints:@[
    [self.topControlView.heightAnchor constraintEqualToAnchor: self.stackView.heightAnchor multiplier: 0.15],
    [self.topControlView.widthAnchor constraintEqualToAnchor: self.stackView.widthAnchor]
  ]];
    self.centerControlView = [[CenterSection alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 100)];
    self.centerControlView.translatesAutoresizingMaskIntoConstraints = NO;
    self.centerControlView.axis = UILayoutConstraintAxisHorizontal;
    self.centerControlView.alignment = UIStackViewAlignmentCenter;
    self.centerControlView.distribution = UIStackViewDistributionEqualCentering;
    self.centerControlView.spacing = 10.0;
    [self.stackView addArrangedSubview:self.centerControlView];
    [NSLayoutConstraint activateConstraints:@[
        [self.centerControlView.heightAnchor constraintEqualToAnchor:self.stackView.heightAnchor multiplier:0.15],
        [self.centerControlView.widthAnchor constraintEqualToAnchor:self.stackView.widthAnchor]
    ]];
  self.bottomControlView = [[BottomSection alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 50)];
  [self.stackView addArrangedSubview: self.bottomControlView];
  [NSLayoutConstraint activateConstraints:@[
    [self.bottomControlView.widthAnchor constraintEqualToAnchor: self.stackView.widthAnchor]
  ]];
   
  
  
}


- (void)handleControlsTap:(UITapGestureRecognizer *)recognizer {
  NSLog(@"tap gesture on stack view");
    // Toggle visibility on tap: if hidden, show and reschedule; if visible, show (to reset timer)
    [self showControlsAnimated:YES];
}

- (void)showControlsAnimated:(BOOL)animated {
    // Cancel any existing timer
    [self invalidateAutoHideTimer];
    if (!_controlsVisible) {
        _controlsVisible = YES;
        CGFloat targetAlpha = 1.0;
        if (animated) {
            [UIView animateWithDuration:0.25 animations:^{
                self.stackView.alpha = targetAlpha;
            }];
        } else {
            self.stackView.alpha = targetAlpha;
        }
    }
    // Always schedule the auto-hide after showing
  if(self.playing == NO) {
    [self scheduleAutoHideControls];
  }
   
}

- (void)hideControlsAnimated:(BOOL)animated {
    if (_controlsVisible) {
        _controlsVisible = NO;
        CGFloat targetAlpha = 0.0;
        void (^hideBlock)(void) = ^{
            self.stackView.alpha = targetAlpha;
        };
        if (animated) {
            [UIView animateWithDuration:0.25 animations:hideBlock];
        } else {
            hideBlock();
        }
    }
}

- (void)scheduleAutoHideControls {
    [self invalidateAutoHideTimer];
    _controlsAutoHideTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(autoHideTimerFired:) userInfo:nil repeats:NO];
}

- (void)invalidateAutoHideTimer {
    if (_controlsAutoHideTimer) {
        [_controlsAutoHideTimer invalidate];
        _controlsAutoHideTimer = nil;
    }
}

- (void)autoHideTimerFired:(NSTimer *)timer {
    [self hideControlsAnimated:YES];
}

@end







