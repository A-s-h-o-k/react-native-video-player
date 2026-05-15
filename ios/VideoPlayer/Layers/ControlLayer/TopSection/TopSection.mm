#import "TopSection.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@implementation TopSection

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
  NSLog(@"logging in initWithFrae in TopSection %f", frame.size.height);
    if (self) {
      self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];
        
      [self setUpUi : frame];
    }
    return self;
}

- (void)setUpUi : (CGRect) frame {
    // configure arranged subviews and constraints here as needed
}

@end
