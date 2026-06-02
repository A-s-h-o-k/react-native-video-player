//
//  Header.h
//  Player
//
//  Created by Ashok Ammineni on 05/02/26.
//

#ifndef Header_h
#define Header_h

#import <UIKit/UIButton.h>
#import <UIKit/UIStackView.h>
#import "../ControlLayer.h"

@class ControlLayer;

@interface CenterSection : UIStackView

@property(nonatomic, strong) UIButton * playButton;
@property(nonatomic, strong) UIButton * forwardButton;
@property(nonatomic, strong) UIButton * backwardButton;
@property(nonatomic, strong) ControlLayer * controlLayer;

-(instancetype) initWithFrame:(CGRect)frame;

@end
#endif /* Header_h */

