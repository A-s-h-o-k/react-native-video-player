#import "ControlLayer.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@implementation ControlLayer

UIImage *playImage = [UIImage systemImageNamed:@"play.fill"];
UIImage *pauseImage = [UIImage systemImageNamed:@"pause.fill"];
UIImage *backwardImage = [UIImage systemImageNamed: @"30.arrow.trianglehead.counterclockwise"];
UIImage *forwardImage = [UIImage systemImageNamed:@"30.arrow.trianglehead.clockwise"];
UIColor *lightTransparent = [UIColor colorWithWhite:0.1 alpha:0.5];
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
    [self.playButton setImage:playImage forState:UIControlStateNormal];
  } else {
    [self.player play];
    self.playing = YES;
    [self.playButton setImage:pauseImage forState:UIControlStateNormal];
  }
}
- (void)setupUI: (CGRect) frame {
    
    // control layer main stack view
    self.stackView = [[UIStackView alloc] init];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisHorizontal; // or Vertical depending on your design
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
    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.alignment = UIStackViewAlignmentFill;
    buttonStack.distribution = UIStackViewDistributionEqualCentering;
    buttonStack.spacing = 10.0;
  [self.stackView addArrangedSubview:buttonStack];
//  [NSLayoutConstraint activateConstraints:@[
//      [buttonStack.centerXAnchor constraintEqualToAnchor:self.stackView.centerXAnchor],
//      [buttonStack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.stackView.leadingAnchor constant:20.0],
//      [buttonStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.stackView.trailingAnchor constant:-20.0]
//  ]];
  
    
    // Create play button
    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playButton setBackgroundColor:lightTransparent];
    [self.playButton setImage:playImage forState:UIControlStateNormal];
    self.playButton.tintColor = UIColor.whiteColor;
    self.playButton.clipsToBounds = YES;
  self.playButton.layer.cornerRadius = 80/2;
    [self.playButton addTarget:self action:@selector(onPausePressed) forControlEvents:UIControlEventTouchUpInside];
  self.backward = [UIButton buttonWithType:UIButtonTypeSystem];
  self.backward.translatesAutoresizingMaskIntoConstraints = NO;
  [self.backward setBackgroundColor:lightTransparent];
  [self.backward setImage:backwardImage forState:UIControlStateNormal];
  self.backward.tintColor = UIColor.whiteColor;
  self.backward.clipsToBounds = YES;
self.backward.layer.cornerRadius = 80/2;
  self.forward = [UIButton buttonWithType:UIButtonTypeSystem];
  self.forward.translatesAutoresizingMaskIntoConstraints = NO;
  [self.forward setBackgroundColor:lightTransparent];
  [self.forward setImage:forwardImage forState:UIControlStateNormal];
  self.forward.tintColor = UIColor.whiteColor;
  self.forward.clipsToBounds = YES;
self.forward.layer.cornerRadius = 80/2;
  [buttonStack addArrangedSubview:self.backward];
  [buttonStack addArrangedSubview:self.playButton];
  [buttonStack addArrangedSubview:self.forward];
  buttonStack.layoutMargins = UIEdgeInsetsMake(0, 40, 0, 40);
  buttonStack.layoutMarginsRelativeArrangement = YES;
    [NSLayoutConstraint activateConstraints:@[
        [self.playButton.widthAnchor constraintEqualToConstant:80.0],
        [self.playButton.heightAnchor constraintEqualToConstant:80.0]
    ]];
  [NSLayoutConstraint activateConstraints:@[
      [self.backward.widthAnchor constraintEqualToConstant:80.0],
      [self.backward.heightAnchor constraintEqualToConstant:80.0]
  ]];
  [NSLayoutConstraint activateConstraints:@[
      [self.forward.widthAnchor constraintEqualToConstant:80.0],
      [self.forward.heightAnchor constraintEqualToConstant:80.0]
  ]];
    [self scheduleAutoHideControls];
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


