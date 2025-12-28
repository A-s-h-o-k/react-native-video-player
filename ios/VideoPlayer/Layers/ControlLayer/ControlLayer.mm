#import "ControlLayer.h"
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@implementation ControlLayer
 
UIImage *playImage = [UIImage systemImageNamed:@"play.fill"];
UIImage *pauseImage = [UIImage systemImageNamed:@"pause.fill"];
UIColor *lightTransparent = [UIColor colorWithWhite:0.1 alpha:0.5];


- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setupUI];
    }
    self.playing = NO;
    self.backgroundColor = UIColor.clearColor;
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
    self.stackView = [[UIStackView alloc] initWithFrame:self.frame];
    CGRect buttonFrame = CGRectMake(0, 0, 80, 80);
    self.playButton = [[UIButton alloc] initWithFrame:buttonFrame];
    [self.playButton setBackgroundColor:lightTransparent];
    [self addSubview:self.stackView];
    [self.stackView addArrangedSubview:self.playButton];
    [self.playButton addTarget:self action:@selector(onPausePressed) forControlEvents:UIControlEventTouchUpInside];
    [self.playButton setImage:playImage forState:UIControlStateNormal];
    self.playButton.tintColor = UIColor.whiteColor;
   self.stackView.backgroundColor = UIColor.clearColor;
   self.stackView.alignment = UIStackViewAlignmentCenter;
  self.stackView.distribution = UIStackViewDistributionFill;
  

}

-(void) layoutSubviews {
  self.stackView.frame = self.frame;
}

@end
