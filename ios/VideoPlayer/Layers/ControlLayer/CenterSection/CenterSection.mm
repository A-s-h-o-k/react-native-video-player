//
//  CenterSection.m
//  Player
//
//  Created by Ashok Ammineni on 05/02/26.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>


#import "CenterSection.h"



@implementation CenterSection

UIImage *playImage = [UIImage systemImageNamed:@"play.fill"];
UIImage *pauseImage = [UIImage systemImageNamed:@"pause.fill"];
UIImage *backwardImage = [UIImage systemImageNamed: @"15.arrow.trianglehead.counterclockwise"];
UIImage *forwardImage = [UIImage systemImageNamed:@"15.arrow.trianglehead.clockwise"];
UIColor *lightTransparent = [UIColor colorWithWhite:0.1 alpha:0.5];

- (instancetype)initWithFrame:(CGRect)frame {
  
  self = [super initWithFrame: frame];
  [self setUpUi];
  return self;
}

- (void) setUpUi {
  self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
  [self.playButton setBackgroundColor:lightTransparent];
  [self.playButton setImage:playImage forState:UIControlStateNormal];
  self.playButton.tintColor = UIColor.whiteColor;
  self.playButton.clipsToBounds = YES;
self.playButton.layer.cornerRadius = 80/2;
//  [self.playButton addTarget:self action:@selector(onPausePressed) forControlEvents:UIControlEventTouchUpInside];
self.backwardButton = [UIButton buttonWithType:UIButtonTypeSystem];
self.backwardButton.translatesAutoresizingMaskIntoConstraints = NO;
[self.backwardButton setBackgroundColor:lightTransparent];
[self.backwardButton setImage:backwardImage forState:UIControlStateNormal];
self.backwardButton.tintColor = UIColor.whiteColor;
self.backwardButton.clipsToBounds = YES;
self.backwardButton.layer.cornerRadius = 80/2;
self.forwardButton = [UIButton buttonWithType:UIButtonTypeSystem];
self.forwardButton.translatesAutoresizingMaskIntoConstraints = NO;
[self.forwardButton setBackgroundColor:lightTransparent];
[self.forwardButton setImage:forwardImage forState:UIControlStateNormal];
self.forwardButton.tintColor = UIColor.whiteColor;
self.forwardButton.clipsToBounds = YES;
self.forwardButton.layer.cornerRadius = 80/2;
[self addArrangedSubview:self.backwardButton];
[self addArrangedSubview:self.playButton];
[self addArrangedSubview:self.forwardButton];
  

[NSLayoutConstraint activateConstraints:@[
    [self.playButton.widthAnchor constraintEqualToConstant:80.0],
    [self.playButton.heightAnchor constraintEqualToConstant:80.0]
]];
[NSLayoutConstraint activateConstraints:@[
    [self.backwardButton.widthAnchor constraintEqualToConstant:80.0],
    [self.backwardButton.heightAnchor constraintEqualToConstant:80.0]
]];
[NSLayoutConstraint activateConstraints:@[
    [self.forwardButton.widthAnchor constraintEqualToConstant:80.0],
    [self.forwardButton.heightAnchor constraintEqualToConstant:80.0]
]];
}





@end

