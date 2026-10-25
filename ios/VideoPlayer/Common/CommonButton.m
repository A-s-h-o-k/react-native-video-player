//
//  CommonButton.m
//  Player
//
//  Created by Ashok Ammineni on 10/01/26.
//

#import "CommonButton.h"

@interface CommonButton ()
@property (nonatomic, assign) CGFloat resolvedDimension;
@end

@implementation CommonButton

- (instancetype)initWithSize:(CommonButtonSize)size style:(CommonButtonStyle)style {
  self = [super initWithFrame:CGRectZero];
  if (self) {
    _buttonSize = size;
    _buttonStyle = style;
    [self commonInit];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _buttonSize = CommonButtonSizeMedium;
    _buttonStyle = CommonButtonStyleTranslucentCircle;
    [self commonInit];
  }
  return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    _buttonSize = CommonButtonSizeMedium;
    _buttonStyle = CommonButtonStyleTranslucentCircle;
    [self commonInit];
  }
  return self;
}

- (void)commonInit {
  self.translatesAutoresizingMaskIntoConstraints = NO;
  self.tintColor = UIColor.whiteColor;
  self.clipsToBounds = YES;
  self.isAccessibilityElement = YES;
  self.accessibilityTraits = UIAccessibilityTraitButton;

  // Touch down / up animations
  [self addTarget:self action:@selector(handleTouchDown) forControlEvents:UIControlEventTouchDown];
  [self addTarget:self action:@selector(handleTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];

  [self applyStyleAndSize];
}

- (void)setButtonSize:(CommonButtonSize)buttonSize {
  _buttonSize = buttonSize;
  [self applyStyleAndSize];
}

- (void)setButtonStyle:(CommonButtonStyle)buttonStyle {
  _buttonStyle = buttonStyle;
  [self applyStyleAndSize];
}

- (void)applyStyleAndSize {
  switch (self.buttonSize) {
    case CommonButtonSizeSmall:
      self.resolvedDimension = 36.0;
      break;
    case CommonButtonSizeMedium:
      self.resolvedDimension = 48.0;
      break;
    case CommonButtonSizeLarge:
      self.resolvedDimension = 72.0;
      break;
    case CommonButtonSizeCustom:
      self.resolvedDimension = self.bounds.size.width > 0 ? self.bounds.size.width : 48.0;
      break;
  }

  // Style background
  switch (self.buttonStyle) {
    case CommonButtonStyleTranslucentCircle:
      self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.55];
      self.layer.cornerRadius = self.resolvedDimension / 2.0;
      break;
    case CommonButtonStyleClear:
      self.backgroundColor = UIColor.clearColor;
      self.layer.cornerRadius = 0;
      break;
    case CommonButtonStyleSolid:
      self.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
      self.layer.cornerRadius = self.resolvedDimension / 2.0;
      break;
  }

  [self invalidateIntrinsicContentSize];
}

- (CGSize)intrinsicContentSize {
  return CGSizeMake(self.resolvedDimension, self.resolvedDimension);
}

#pragma mark - SF Symbol Helper

- (void)setSystemIcon:(NSString *)iconName pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight {
  UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
  UIImage *image = [UIImage systemImageNamed:iconName withConfiguration:config];
  [self setImage:image forState:UIControlStateNormal];
}

#pragma mark - Minimum 44x44pt Touch Target (Apple HIG)

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  CGFloat minDimension = 44.0;
  CGFloat deltaWidth = MAX(minDimension - self.bounds.size.width, 0);
  CGFloat deltaHeight = MAX(minDimension - self.bounds.size.height, 0);
  CGRect hitFrame = CGRectInset(self.bounds, -deltaWidth / 2.0, -deltaHeight / 2.0);
  return CGRectContainsPoint(hitFrame, point);
}

#pragma mark - Micro-Interaction Animations

- (void)handleTouchDown {
  [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
    self.transform = CGAffineTransformMakeScale(0.92, 0.92);
  } completion:nil];
}

- (void)handleTouchUp {
  [UIView animateWithDuration:0.15 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
    self.transform = CGAffineTransformIdentity;
  } completion:^(BOOL finished) {
    if (self.onTap) {
      self.onTap(self);
    }
  }];
}

#pragma mark - tvOS Remote / D-pad Focus Support

#if TARGET_OS_TV
- (BOOL)canBecomeFocused {
  return YES;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
  [coordinator addCoordinatedAnimations:^{
    if (self.isFocused) {
      self.transform = CGAffineTransformMakeScale(1.15, 1.15);
      self.layer.borderWidth = 2.0;
      self.layer.borderColor = UIColor.whiteColor.CGColor;
    } else {
      self.transform = CGAffineTransformIdentity;
      self.layer.borderWidth = 0.0;
    }
  } completion:nil];
}
#endif

#pragma mark - Accessibility

- (void)configureAccessibilityWithLabel:(NSString *)label hint:(nullable NSString *)hint {
  self.accessibilityLabel = label;
  self.accessibilityHint = hint;
}

@end
