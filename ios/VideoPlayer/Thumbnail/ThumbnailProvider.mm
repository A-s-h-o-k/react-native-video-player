//
//  ThumbnailProvider.mm
//  Player
//
//  Dedicated, asynchronous Thumbnail Provider implementation for iOS & tvOS.
//

#import "ThumbnailProvider.h"

@interface ThumbnailProvider ()
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *imageCache;
@property (nonatomic, strong) dispatch_queue_t backgroundQueue;
@end

@implementation ThumbnailProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _imageCache = [[NSCache alloc] init];
        _imageCache.totalCostLimit = 20 * 1024 * 1024; // 20 MB memory limit
        _backgroundQueue = dispatch_queue_create("com.player.thumbnail.generator", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)loadThumbnailForURL:(nullable NSURL *)url
                artworkData:(nullable NSData *)artworkData
                 completion:(void (^)(UIImage * _Nullable image))completion {
    if (!url && !artworkData) {
        if (completion) completion(nil);
        return;
    }

    NSString *cacheKey = (artworkData != nil)
        ? [NSString stringWithFormat:@"data_%lu_%lu", (unsigned long)artworkData.length, (unsigned long)artworkData.hash]
        : url.absoluteString;

    // 1. Check in-memory cache
    UIImage *cached = [self.imageCache objectForKey:cacheKey];
    if (cached) {
        if (completion) completion(cached);
        return;
    }

    // 2. Decode embedded artwork data
    if (artworkData && artworkData.length > 0) {
        dispatch_async(self.backgroundQueue, ^{
            UIImage *decoded = [UIImage imageWithData:artworkData];
            if (decoded) {
                [self.imageCache setObject:decoded forKey:cacheKey cost:(NSUInteger)(decoded.size.width * decoded.size.height * 4)];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(decoded);
            });
        });
        return;
    }

    // 3. Fallback: Asynchronously extract video frame at 1.0 second via AVAssetImageGenerator
    if (!url) {
        if (completion) completion(nil);
        return;
    }

    dispatch_async(self.backgroundQueue, ^{
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.maximumSize = CGSizeMake(1280, 720);

        CMTime thumbTime = CMTimeMakeWithSeconds(1.0, 600);
        NSError *error = nil;
        CMTime actualTime;
        CGImageRef imageRef = [generator copyCGImageAtTime:thumbTime actualTime:&actualTime error:&error];

        UIImage *thumbImage = nil;
        if (imageRef && !error) {
            thumbImage = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
            [self.imageCache setObject:thumbImage forKey:cacheKey cost:(NSUInteger)(thumbImage.size.width * thumbImage.size.height * 4)];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(thumbImage);
        });
    });
}

- (void)clearCache {
    [self.imageCache removeAllObjects];
}

@end
