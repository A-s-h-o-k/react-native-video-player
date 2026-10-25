//
//  BottomSection.mm
//  Player
//
//  Created by Ashok Ammineni on 10/05/26.
//

#import "BottomSection.h"
#import <Foundation/Foundation.h>

@interface BottomSection () {
    NSTimeInterval _duration;
}
@property (nonatomic, assign, readwrite) BOOL isScrubbing;
@end

@implementation BottomSection

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _duration = 0.0;
        _isScrubbing = NO;
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
    self.layoutMargins = UIEdgeInsetsMake(0, 16.0, 8.0, 16.0);
    self.layoutMarginsRelativeArrangement = YES;

    // 1. Current Elapsed Time Label
    self.currentTimeLabel = [[UILabel alloc] init];
    self.currentTimeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.currentTimeLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.currentTimeLabel.textColor = UIColor.whiteColor;
    self.currentTimeLabel.text = @"00:00";
    self.currentTimeLabel.textAlignment = NSTextAlignmentCenter;
    [self.currentTimeLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.currentTimeLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    // 2. High-Precision 60fps Scrubber Slider
    self.timeTrack = [[UISlider alloc] init];
    self.timeTrack.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeTrack.minimumValue = 0.0;
    self.timeTrack.maximumValue = 1.0;
    self.timeTrack.value = 0.0;
    self.timeTrack.continuous = YES;
    self.timeTrack.minimumTrackTintColor = UIColor.whiteColor;
    self.timeTrack.maximumTrackTintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
    self.timeTrack.isAccessibilityElement = YES;
    self.timeTrack.accessibilityLabel = @"Video timeline scrubber";
    self.timeTrack.accessibilityTraits = UIAccessibilityTraitAdjustable;

    // Attach touch target actions
    [self.timeTrack addTarget:self action:@selector(sliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.timeTrack addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.timeTrack addTarget:self action:@selector(sliderTouchUp:) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel)];

    // 3. Total Duration Label
    self.durationLabel = [[UILabel alloc] init];
    self.durationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightMedium];
    self.durationLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    self.durationLabel.text = @"00:00";
    self.durationLabel.textAlignment = NSTextAlignmentCenter;
    [self.durationLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.durationLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    // 4. Fullscreen Button (Small circular CommonButton)
    self.fullscreenButton = [[CommonButton alloc] initWithSize:CommonButtonSizeSmall style:CommonButtonStyleTranslucentCircle];
    [self.fullscreenButton setSystemIcon:@"arrow.up.left.and.arrow.down.right" pointSize:16 weight:UIImageSymbolWeightSemibold];
    [self.fullscreenButton configureAccessibilityWithLabel:@"Fullscreen" hint:@"Toggles fullscreen display"];
    __weak BottomSection *weakSelf = self;
    self.fullscreenButton.onTap = ^(CommonButton * _Nonnull button) {
        BottomSection *strongSelf = weakSelf;
        if (strongSelf && [strongSelf.delegate respondsToSelector:@selector(bottomSectionDidTapFullscreen:)]) {
            [strongSelf.delegate bottomSectionDidTapFullscreen:strongSelf];
        }
    };

    [self addArrangedSubview:self.currentTimeLabel];
    [self addArrangedSubview:self.timeTrack];
    [self addArrangedSubview:self.durationLabel];
    [self addArrangedSubview:self.fullscreenButton];
}

#pragma mark - Scrubber Touch Actions

- (void)sliderTouchDown:(UISlider *)sender {
    self.isScrubbing = YES;
    if ([self.delegate respondsToSelector:@selector(bottomSectionDidStartScrubbing:)]) {
        [self.delegate bottomSectionDidStartScrubbing:self];
    }
}

- (void)sliderValueChanged:(UISlider *)sender {
    self.currentTimeLabel.text = [self stringFromSeconds:sender.value];
    if ([self.delegate respondsToSelector:@selector(bottomSection:didScrubToTime:)]) {
        [self.delegate bottomSection:self didScrubToTime:sender.value];
    }
}

- (void)sliderTouchUp:(UISlider *)sender {
    self.isScrubbing = NO;
    if ([self.delegate respondsToSelector:@selector(bottomSection:didEndScrubbing:)]) {
        [self.delegate bottomSection:self didEndScrubbing:sender.value];
    }
}

#pragma mark - State Updates

- (void)updateCurrentTime:(NSTimeInterval)currentTime duration:(NSTimeInterval)duration {
    _duration = duration;

    // Do not overwrite slider position if user is actively dragging the thumb
    if (!self.isScrubbing) {
        if (duration > 0.0) {
            self.timeTrack.maximumValue = duration;
            self.timeTrack.value = currentTime;
        } else {
            self.timeTrack.maximumValue = 1.0;
            self.timeTrack.value = 0.0;
        }
        self.currentTimeLabel.text = [self stringFromSeconds:currentTime];
    }

    self.durationLabel.text = [self stringFromSeconds:duration];
}

- (void)setAccentColor:(UIColor *)color {
    if (color) {
        self.timeTrack.minimumTrackTintColor = color;
    }
}

#pragma mark - Helper

- (NSString *)stringFromSeconds:(NSTimeInterval)totalSeconds {
    if (isnan(totalSeconds) || totalSeconds < 0.0) {
        return @"00:00";
    }

    NSInteger seconds = (NSInteger)round(totalSeconds);
    NSInteger hours = seconds / 3600;
    NSInteger minutes = (seconds % 3600) / 60;
    NSInteger secs = seconds % 60;

    if (hours > 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)secs];
    } else {
        return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)secs];
    }
}

@end
