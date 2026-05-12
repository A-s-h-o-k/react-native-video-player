//
//  Header.h
//  Player
//
//  Created by Ashok Ammineni on 05/02/26.
//

#ifndef Header_h
#define Header_h

#import <UIKit/UIkit.h>



#endif /* Header_h */

@interface CenterSection : UIStackView

@property(nonatomic, strong) UIButton * playButton;
@property(nonatomic, strong) UIButton * forwardButton;
@property(nonatomic, strong) UIButton * backwardButton;

-(instancetype) initWithFrame:(CGRect)frame;

@end
