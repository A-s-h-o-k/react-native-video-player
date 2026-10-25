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

@interface ControlLayer : UIView <CenterSectionDelegate, BottomSectionDelegate, TopSectionDelegate>

@property (nonatomic, assign) BOOL playing;
@property (nonatomic, strong, nullable) AVPlayer *player;

@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) TopSection *topControlView;
@property (nonatomic, strong) CenterSection *centerControlView;
@property (nonatomic, strong) BottomSection *bottomControlView;
@property (nonatomic, strong) UIActivityIndicatorView *bufferingSpinner;

#ifdef __cplusplus
- (void)setCoordinator:(nullable PlayerCore::PlayerStateCoordinator *)coordinator;
#endif

- (void)setVideoPlayer:(AVPlayer *)player;
- (void)setTitle:(nullable NSString *)title;
- (void)showControlsAnimated:(BOOL)animated;
- (void)hideControlsAnimated:(BOOL)animated;
- (void)resetAutoHideTimer;

@end

NS_ASSUME_NONNULL_END
