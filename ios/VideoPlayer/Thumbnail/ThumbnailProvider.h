//
//  ThumbnailProvider.h
//  Player
//
//  Dedicated, asynchronous Thumbnail Provider for iOS & tvOS.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ThumbnailProvider : NSObject

- (void)loadThumbnailForURL:(nullable NSURL *)url
                artworkData:(nullable NSData *)artworkData
                 completion:(void (^)(UIImage * _Nullable image))completion;

- (void)clearCache;

@end

NS_ASSUME_NONNULL_END
