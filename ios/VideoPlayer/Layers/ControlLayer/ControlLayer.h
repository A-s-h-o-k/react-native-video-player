//
//  ControlLayer.h
//  Player
//
//  Created by Ashok Ammineni on 25/12/25.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "./TopSection/TopSection.h"
#import "./CenterSection/CenterSection.h"
#import "./BottomSection/BottomSection.h"

#ifdef __cplusplus
#import "../../../cpp/PlayerStateCoordinator.hpp"
#import "../../../cpp/IPlayerStateObserver.hpp"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface ControlLayer : UIView <CenterSectionDelegate, BottomSectionDelegate, TopSectionDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, strong, nullable) AVPlayer *player;

@property (nonatomic, strong) UIView *controlsContainerView;
@property (nonatomic, strong) UIView *stackView;
@property (nonatomic, strong) CAGradientLayer *topGradientLayer;
@property (nonatomic, strong) CAGradientLayer *bottomGradientLayer;
@property (nonatomic, strong) TopSection *topControlView;
@property (nonatomic, strong) CenterSection *centerControlView;
@property (nonatomic, strong) BottomSection *bottomControlView;
@property (nonatomic, strong) UIActivityIndicatorView *bufferingSpinner;

@property (nonatomic, assign, readonly) BOOL isFullscreen;
@property (nonatomic, assign) BOOL autoAdjustSafeArea;
@property (nonatomic, copy, nullable) void (^onFullscreenToggleRequested)(BOOL isFullscreen);

#ifdef __cplusplus
- (void)setCoordinator:(nullable PlayerCore::PlayerStateCoordinator *)coordinator;
#endif

- (void)setVideoPlayer:(AVPlayer *)player;
- (void)setTitle:(nullable NSString *)title;
- (void)setFullscreen:(BOOL)isFullscreen;
- (void)setShowFullscreenButton:(BOOL)show;
- (void)setAutoAdjustSafeArea:(BOOL)autoAdjust;
- (void)setIconsJSON:(nullable NSString *)iconsJSON;
- (void)setAccentColorHex:(nullable NSString *)colorHex;
- (void)setTrackColorHex:(nullable NSString *)colorHex;
- (void)setBufferColorHex:(nullable NSString *)colorHex;
- (void)setSkipIntervalSeconds:(NSInteger)seconds;
- (void)setShowRewindButton:(BOOL)show;
- (void)setShowForwardButton:(BOOL)show;
- (void)setShowPlayPauseButton:(BOOL)show;
- (void)setAutoHideTimeoutMs:(NSInteger)timeoutMs;
- (void)setControlsVisible:(BOOL)visible;
- (void)showControlsAnimated:(BOOL)animated;
- (void)hideControlsAnimated:(BOOL)animated;
- (void)resetAutoHideTimer;

@end

NS_ASSUME_NONNULL_END
