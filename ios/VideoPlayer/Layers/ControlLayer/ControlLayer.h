//
//  ControlLayer.h
//  Player
//
//  Created by Ashok Ammineni on 25/12/25.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIView.h>
#import <UIKit/UIButton.h>
#import <AVFoundation/AVPlayerLayer.h>
#import <UIKit/UIKit.h>



#ifndef ControlLayer_h
#define ControlLayer_h

@interface ControlLayer : UIView

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, strong) AVPlayer * player;
//@property (nonatomic, strong) UIButton * playButton;
@property (nonatomic, strong) UIButton * nextButton;
@property (nonatomic, strong) UIButton * previousButton;
@property (nonatomic, strong) UIStackView * stackView;
@property (nonatomic, strong) UIButton * forward;
@property (nonatomic, strong) UIButton * backward;
@property (nonatomic, strong) UIStackView * topControlView;
@property (nonatomic, strong) UIStackView * centerControlView;
@property (nonatomic, strong) UIStackView * bottomControlView;


-(void) setVideoPlayer: (AVPlayer*) player;
//-(void) onPlay;
//-(void) onPause;

@end


#endif /* ControlLayer_h */
