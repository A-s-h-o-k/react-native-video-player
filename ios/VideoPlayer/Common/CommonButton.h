//
//  CommonButton.h
//  Player
//
//  Created by Ashok Ammineni on 10/01/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CommonButtonSize) {
  CommonButtonSizeSmall,   // 36x36pt
  CommonButtonSizeMedium,  // 48x48pt
  CommonButtonSizeLarge,   // 72x72pt (Center Play/Pause)
  CommonButtonSizeCustom
};

typedef NS_ENUM(NSInteger, CommonButtonStyle) {
  CommonButtonStyleTranslucentCircle, // Dark semi-transparent circle
  CommonButtonStyleClear,             // No background, icon only
  CommonButtonStyleSolid              // Opaque background
};

@interface CommonButton : UIButton

/** Size preset */
@property (nonatomic, assign) CommonButtonSize buttonSize;

/** Visual style preset */
@property (nonatomic, assign) CommonButtonStyle buttonStyle;

/** Block-based tap callback */
@property (nonatomic, copy, nullable) void (^onTap)(CommonButton *button);

/** Designated Initializer with preset size and style */
- (instancetype)initWithSize:(CommonButtonSize)size style:(CommonButtonStyle)style;

/** Convenience factory for system SF Symbol icons */
- (void)setSystemIcon:(NSString *)iconName pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight;

/** Accessibility helper */
- (void)configureAccessibilityWithLabel:(NSString *)label hint:(nullable NSString *)hint;

@end

NS_ASSUME_NONNULL_END
