//
//  CenterSection.h
//  Player
//
//  Created by Ashok Ammineni on 05/02/26.
//

#import <UIKit/UIKit.h>
#import "../../../Common/CommonButton.h"

NS_ASSUME_NONNULL_BEGIN

@class CenterSection;

@protocol CenterSectionDelegate <NSObject>
- (void)centerSectionDidTapPlayPause:(CenterSection *)section;
- (void)centerSection:(CenterSection *)section didTapRewind:(NSTimeInterval)seconds;
- (void)centerSection:(CenterSection *)section didTapForward:(NSTimeInterval)seconds;
@end

@interface CenterSection : UIStackView

@property (nonatomic, strong) CommonButton *playButton;
@property (nonatomic, strong) CommonButton *forwardButton;
@property (nonatomic, strong) CommonButton *backwardButton;

@property (nonatomic, weak, nullable) id<CenterSectionDelegate> delegate;

/** Skip seek interval in seconds (default: 15.0) */
@property (nonatomic, assign) NSTimeInterval skipInterval;

/** Custom icons map */
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *customIcons;

/** Visibility controls */
- (void)setShowRewindButton:(BOOL)show;
- (void)setShowForwardButton:(BOOL)show;
- (void)setShowPlayPauseButton:(BOOL)show;

/** Updates play/pause button icon and accessibility label */
- (void)setPlaying:(BOOL)playing;

/** Updates center button with explicit playback and ended states */
- (void)setPlaying:(BOOL)playing isEnded:(BOOL)ended;

/** Updates center button to replay icon when playback ends */
- (void)setPlaybackEnded:(BOOL)ended;

- (instancetype)initWithFrame:(CGRect)frame;

@end

NS_ASSUME_NONNULL_END
