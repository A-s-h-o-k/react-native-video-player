//
//  AVPlayerAdapter.h
//  Player
//
//  Bridge adapter connecting AVPlayer to PlayerStateCoordinator.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

#ifdef __cplusplus
#import "../../../cpp/PlayerStateCoordinator.hpp"
#endif

NS_ASSUME_NONNULL_BEGIN

@class NetworkAuthManager;

@interface AVPlayerAdapter : NSObject

@property (nonatomic, strong, readonly, nullable) AVPlayer *player;
@property (nonatomic, strong, readonly) NetworkAuthManager *networkAuthManager;
@property (nonatomic, copy, nullable) void (^onItemReadyToPlay)(AVPlayerItem *item);

#ifdef __cplusplus
- (instancetype)initWithCoordinator:(PlayerCore::PlayerStateCoordinator *)coordinator;
- (void)attachPlayer:(AVPlayer *)player;
- (void)detachPlayer;
#endif

- (void)configureHeaders:(nullable NSDictionary<NSString *, NSString *> *)headers
               drmConfig:(nullable NSDictionary<NSString *, id> *)drmConfig;

- (void)loadURL:(NSURL *)url;
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
