//
//  MediaMetadataResolver.h
//  Player
//
//  Dedicated metadata resolver for iOS & tvOS.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MediaMetadataInfo : NSObject

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly, nullable) NSString *artist;
@property (nonatomic, strong, readonly, nullable) NSData *artworkData;

- (instancetype)initWithTitle:(NSString *)title
                       artist:(nullable NSString *)artist
                  artworkData:(nullable NSData *)artworkData;

@end

@interface MediaMetadataResolver : NSObject

- (MediaMetadataInfo *)resolveWithExplicitTitle:(nullable NSString *)explicitTitle
                                     playerItem:(nullable AVPlayerItem *)playerItem
                                            url:(nullable NSURL *)url;

- (NSString *)deriveTitleFromURL:(nullable NSURL *)url;

@end

NS_ASSUME_NONNULL_END
