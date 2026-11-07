//
//  OrientationManager.h
//  Player
//
//  Created for dynamic cross-platform fullscreen orientation coordination.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OrientationManager : NSObject

+ (UIInterfaceOrientationMask)supportedInterfaceOrientations;
+ (void)setSupportedInterfaceOrientations:(UIInterfaceOrientationMask)mask;

@end

NS_ASSUME_NONNULL_END
