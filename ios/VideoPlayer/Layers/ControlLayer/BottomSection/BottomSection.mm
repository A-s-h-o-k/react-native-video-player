//
//  BottomSection.m
//  Player
//
//  Created by Ashok Ammineni on 10/05/26.
//

#import <Foundation/Foundation.h>
#import "BottomSection.h"


@implementation BottomSection

- (instancetype)initWithFrame:(CGRect) frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self setUpUi: frame];
  }
  return self;
}

-(void) setUpUi : (CGRect) frame {
  self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];
  self.timeTrack = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 10)];
  self.timeTrack.minimumValue = 0;
  self.timeTrack.maximumValue = 30;
  [self addArrangedSubview:self.timeTrack];
}

@end
