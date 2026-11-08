//
//  TopSection.h
//  Player
//
//  Created by Ashok Ammineni on 10/05/26.
//

#import <UIKit/UIKit.h>
#import "../../../Common/CommonButton.h"

NS_ASSUME_NONNULL_BEGIN

@class TopSection;

@protocol TopSectionDelegate <NSObject>
- (void)topSectionDidTapBack:(TopSection *)section;
- (void)topSectionDidTapCaptions:(TopSection *)section;
- (void)topSectionDidTapSettings:(TopSection *)section;
@end

@interface TopSection : UIStackView

@property (nonatomic, weak, nullable) id<TopSectionDelegate> delegate;

@property (nonatomic, strong) CommonButton *backButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIStackView *actionsStackView;
@property (nonatomic, strong) CommonButton *captionsButton;
@property (nonatomic, strong) CommonButton *settingsButton;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)setTitle:(nullable NSString *)title;
- (void)setCaptionsVisible:(BOOL)visible;
- (void)setCaptionsActive:(BOOL)active;

@end

NS_ASSUME_NONNULL_END
