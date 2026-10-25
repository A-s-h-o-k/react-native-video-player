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
#import "../../../cpp/IPlaybackEngineBridge.hpp"
#endif

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
class AVPlayerBridgeImpl : public PlayerCore::IPlaybackEngineBridge {
public:
    AVPlayerBridgeImpl(AVPlayer *player);
    virtual ~AVPlayerBridgeImpl() = default;

    void setPlayer(AVPlayer * _Nullable player);

    void executePlay() override;
    void executePause() override;
    void executeSeek(double seconds) override;
    void executePlaybackRate(float rate) override;
    void executeVolume(float volume) override;
    void executeMute(bool muted) override;

private:
    __weak AVPlayer *player_;
};
#endif

@class NetworkAuthManager;

@interface AVPlayerAdapter : NSObject

@property (nonatomic, strong, readonly, nullable) AVPlayer *player;
@property (nonatomic, strong, readonly) NetworkAuthManager *networkAuthManager;

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
