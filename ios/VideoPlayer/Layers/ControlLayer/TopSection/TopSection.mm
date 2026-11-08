//
//  TopSection.mm
//  Player
//
//  Created by Ashok Ammineni on 10/05/26.
//

#import "TopSection.h"
#import <Foundation/Foundation.h>

@implementation TopSection

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.axis = UILayoutConstraintAxisHorizontal;
    self.alignment = UIStackViewAlignmentCenter;
    self.distribution = UIStackViewDistributionFill;
    self.spacing = 12.0;
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.insetsLayoutMarginsFromSafeArea = NO;
    self.layoutMargins = UIEdgeInsetsMake(8.0, 16.0, 8.0, 16.0);
    self.layoutMarginsRelativeArrangement = YES;

    // 1. Navigation Back Button (Small CommonButton)
    self.backButton = [[CommonButton alloc] initWithSize:CommonButtonSizeSmall style:CommonButtonStyleTranslucentCircle];
    [self.backButton setSystemIcon:@"chevron.backward" pointSize:16 weight:UIImageSymbolWeightSemibold];
    [self.backButton configureAccessibilityWithLabel:@"Back" hint:@"Navigates back or closes the video player"];
    [self.backButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.backButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    __weak TopSection *weakSelf = self;
    self.backButton.onTap = ^(CommonButton * _Nonnull button) {
        TopSection *strongSelf = weakSelf;
        if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(topSectionDidTapBack:)]) {
            [strongSelf.delegate topSectionDidTapBack:strongSelf];
        }
    };

    // 2. Video Title Label
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
    self.titleLabel.shadowOffset = CGSizeMake(0, 1);
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.text = @"";
    [self.titleLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    // 3. Right Secondary Actions Stack (Captions + Settings)
    self.actionsStackView = [[UIStackView alloc] init];
    self.actionsStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.actionsStackView.axis = UILayoutConstraintAxisHorizontal;
    self.actionsStackView.alignment = UIStackViewAlignmentCenter;
    self.actionsStackView.spacing = 8.0;
    [self.actionsStackView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.actionsStackView setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    // 3a. Captions / Subtitles Button
    self.captionsButton = [[CommonButton alloc] initWithSize:CommonButtonSizeSmall style:CommonButtonStyleTranslucentCircle];
    [self.captionsButton setSystemIcon:@"captions.bubble" pointSize:15 weight:UIImageSymbolWeightMedium];
    [self.captionsButton configureAccessibilityWithLabel:@"Audio and subtitles" hint:@"Selects audio tracks and subtitles"];
    self.captionsButton.onTap = ^(CommonButton * _Nonnull button) {
        TopSection *strongSelf = weakSelf;
        if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(topSectionDidTapCaptions:)]) {
            [strongSelf.delegate topSectionDidTapCaptions:strongSelf];
        }
    };

    // 3b. Settings / Overflow Button
    self.settingsButton = [[CommonButton alloc] initWithSize:CommonButtonSizeSmall style:CommonButtonStyleTranslucentCircle];
    [self.settingsButton setSystemIcon:@"gearshape" pointSize:15 weight:UIImageSymbolWeightMedium];
    [self.settingsButton configureAccessibilityWithLabel:@"Settings" hint:@"Adjusts playback speed and video quality"];
    self.settingsButton.onTap = ^(CommonButton * _Nonnull button) {
        TopSection *strongSelf = weakSelf;
        if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(topSectionDidTapSettings:)]) {
            [strongSelf.delegate topSectionDidTapSettings:strongSelf];
        }
    };

    [self.actionsStackView addArrangedSubview:self.captionsButton];
    [self.actionsStackView addArrangedSubview:self.settingsButton];

    // Assemble Main Stack
    [self addArrangedSubview:self.backButton];
    [self addArrangedSubview:self.titleLabel];
    [self addArrangedSubview:self.actionsStackView];
}

- (void)setTitle:(NSString *)title {
    self.titleLabel.text = title ?: @"";
}

- (void)setCaptionsVisible:(BOOL)visible {
    self.captionsButton.hidden = !visible;
}

- (void)setCaptionsActive:(BOOL)active {
    self.captionsButton.alpha = active ? 1.0 : 0.5;
}

@end
