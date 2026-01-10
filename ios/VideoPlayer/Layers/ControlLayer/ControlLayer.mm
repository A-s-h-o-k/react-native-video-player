#import "ControlLayer.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@implementation ControlLayer

UIImage *playImage = [UIImage systemImageNamed:@"play.fill"];
UIImage *pauseImage = [UIImage systemImageNamed:@"pause.fill"];
UIColor *lightTransparent = [UIColor colorWithWhite:0.1 alpha:0.5];
NSTimer *_controlsAutoHideTimer;
BOOL _controlsVisible;

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setupUI];
    }
    self.playing = NO;
    self.backgroundColor = UIColor.clearColor;
    _controlsVisible = YES;
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
- (void)setupUI {
    // Outer stack fills the entire ControlLayer
    self.stackView = [[UIStackView alloc] init];
    self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.stackView.axis = UILayoutConstraintAxisHorizontal; // or Vertical depending on your design
    self.stackView.alignment = UIStackViewAlignmentCenter;  // centers inner content vertically for horizontal axis
    self.stackView.distribution = UIStackViewDistributionFill;
    self.stackView.spacing = 0;
    self.stackView.backgroundColor = UIColor.clearColor;

    [self addSubview:self.stackView];

    // Constrain outer stack to fill parent (inherit width/height)
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
    buttonStack.alignment = UIStackViewAlignmentCenter;
    buttonStack.distribution = UIStackViewDistributionEqualSpacing;
    buttonStack.spacing = 12.0;
    
    [self.stackView addArrangedSubview:buttonStack];

    // Create play button
    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.playButton setBackgroundColor:lightTransparent];
    [self.playButton setImage:playImage forState:UIControlStateNormal];
    self.playButton.tintColor = UIColor.whiteColor;
    self.playButton.clipsToBounds = YES;
  self.playButton.layer.cornerRadius = 80/2;
    [self.playButton addTarget:self action:@selector(onPausePressed) forControlEvents:UIControlEventTouchUpInside];

  
    [NSLayoutConstraint activateConstraints:@[
        [self.playButton.widthAnchor constraintEqualToConstant:80.0],
        [self.playButton.heightAnchor constraintEqualToConstant:80.0]
    ]];

    // Prevent horizontal stretching
    [self.playButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.playButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    // Add button to the inner button stack
    [buttonStack addArrangedSubview:self.playButton];

    // Optional: If you want the button group centered in the outer stack
    // and the outer stack is horizontal, you can pad with flexible spacers:
    UIView *leadingSpacer = [[UIView alloc] init];
    UIView *trailingSpacer = [[UIView alloc] init];
    [leadingSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [trailingSpacer setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    // If you prefer explicit centering without spacers, you can also wrap buttonStack in a container view
    // and center that container via constraints. But spacers work well with stack distributions like Fill.

    // Example using Fill with spacers to center the button group:
    // Clear current arranged subviews and re-add with spacers:
    [self.stackView removeArrangedSubview:buttonStack];
    [buttonStack removeFromSuperview];
    self.stackView.distribution = UIStackViewDistributionFill;

    [self.stackView addArrangedSubview:leadingSpacer];
    [self.stackView addArrangedSubview:buttonStack];
    [self.stackView addArrangedSubview:trailingSpacer];

    // Give spacers equal width so the button stack stays centered
    [leadingSpacer.widthAnchor constraintEqualToAnchor:trailingSpacer.widthAnchor].active = YES;

    [self scheduleAutoHideControls];
}
-(void) layoutSubviews {
  [super layoutSubviews];
//  self.stackView.frame = self.frame;
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
