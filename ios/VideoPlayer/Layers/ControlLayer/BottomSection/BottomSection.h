//
//  BottomSection.h
//  Player
//
//  Created by Ashok Ammineni on 10/05/26.
//

#import <UIKit/UIKit.h>
#import "../../../Common/CommonButton.h"

NS_ASSUME_NONNULL_BEGIN

@class BottomSection;

@protocol BottomSectionDelegate <NSObject>
- (void)bottomSectionDidStartScrubbing:(BottomSection *)section;
- (void)bottomSection:(BottomSection *)section didScrubToTime:(NSTimeInterval)time;
- (void)bottomSection:(BottomSection *)section didEndScrubbing:(NSTimeInterval)time;
- (void)bottomSectionDidTapFullscreen:(BottomSection *)section;
@end

@interface BottomSection : UIStackView

@property (nonatomic, weak, nullable) id<BottomSectionDelegate> delegate;

@property (nonatomic, strong) UILabel *currentTimeLabel;
@property (nonatomic, strong) UISlider *timeTrack;
@property (nonatomic, strong) UIProgressView *bufferProgressView;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) CommonButton *fullscreenButton;

@property (nonatomic, assign, readonly) BOOL isScrubbing;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)updateCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration;
- (void)updateBufferTime:(NSTimeInterval)bufferedTime percentage:(double)percentage;
- (void)setFullscreen:(BOOL)isFullscreen;
- (void)setShowFullscreenButton:(BOOL)show;
- (void)setAccentColor:(UIColor *)color;
- (void)setTrackColor:(UIColor *)color;
- (void)setBufferColor:(UIColor *)color;
- (void)setCustomIcons:(nullable NSDictionary<NSString *, NSString *> *)icons;

@end

NS_ASSUME_NONNULL_END
