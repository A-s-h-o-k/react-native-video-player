//
//  AVPlayerAdapter.mm
//  Player
//
//  Bridge adapter connecting AVPlayer to PlayerStateCoordinator.
//

#import "AVPlayerAdapter.h"
#import "../Network/NetworkAuthManager.h"

static void *AVPlayerAdapterKVOContext = &AVPlayerAdapterKVOContext;

#pragma mark - C++ Bridge Implementation

AVPlayerBridgeImpl::AVPlayerBridgeImpl(AVPlayer *player) : player_(player) {}

void AVPlayerBridgeImpl::setPlayer(AVPlayer *player) {
    player_ = player;
}

void AVPlayerBridgeImpl::executePlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [player_ play];
    });
}

void AVPlayerBridgeImpl::executePause() {
    dispatch_async(dispatch_get_main_queue(), ^{
        [player_ pause];
    });
}

void AVPlayerBridgeImpl::executeSeek(double seconds) {
    dispatch_async(dispatch_get_main_queue(), ^{
        CMTime target = CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC);
        [player_ seekToTime:target toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    });
}

void AVPlayerBridgeImpl::executePlaybackRate(float rate) {
    dispatch_async(dispatch_get_main_queue(), ^{
        player_.rate = rate;
    });
}

void AVPlayerBridgeImpl::executeVolume(float volume) {
    dispatch_async(dispatch_get_main_queue(), ^{
        player_.volume = volume;
    });
}

void AVPlayerBridgeImpl::executeMute(bool muted) {
    dispatch_async(dispatch_get_main_queue(), ^{
        player_.muted = muted;
    });
}

#pragma mark - Objective-C++ Adapter Implementation

@interface AVPlayerAdapter () {
    PlayerCore::PlayerStateCoordinator *_coordinator;
    std::unique_ptr<AVPlayerBridgeImpl> _bridge;
}
@property (nonatomic, strong, readwrite, nullable) AVPlayer *player;
@property (nonatomic, strong, readwrite) NetworkAuthManager *networkAuthManager;
@property (nonatomic, strong, nullable) id timeObserverToken;
@property (nonatomic, assign) BOOL isObservingItem;
@property (nonatomic, assign) BOOL isObservingPlayer;
@end

@implementation AVPlayerAdapter

- (instancetype)initWithCoordinator:(PlayerCore::PlayerStateCoordinator *)coordinator {
    self = [super init];
    if (self) {
        _coordinator = coordinator;
        _bridge = std::make_unique<AVPlayerBridgeImpl>(nil);
        _coordinator->setEngineBridge(_bridge.get());
        _networkAuthManager = [[NetworkAuthManager alloc] init];
    }
    return self;
}

- (void)configureHeaders:(nullable NSDictionary<NSString *, NSString *> *)headers
               drmConfig:(nullable NSDictionary<NSString *, id> *)drmConfig {
    [self.networkAuthManager configureWithHeaders:headers drmConfig:drmConfig];
}

- (void)attachPlayer:(AVPlayer *)player {
    [self detachPlayer];

    self.player = player;
    _bridge->setPlayer(player);

    if (self.player) {
        [self.player addObserver:self
                      forKeyPath:@"timeControlStatus"
                         options:NSKeyValueObservingOptionNew
                         context:AVPlayerAdapterKVOContext];
        _isObservingPlayer = YES;

        // Periodic time observer (4 updates per second)
        __weak AVPlayerAdapter *weakSelf = self;
        CMTime interval = CMTimeMake(1, 4);
        self.timeObserverToken = [self.player addPeriodicTimeObserverForInterval:interval
                                                                           queue:dispatch_get_main_queue()
                                                                      usingBlock:^(CMTime time) {
            AVPlayerAdapter *strongSelf = weakSelf;
            if (!strongSelf || !strongSelf->_coordinator) { return; }
            double seconds = CMTimeGetSeconds(time);
            if (!isnan(seconds) && seconds >= 0.0) {
                strongSelf->_coordinator->notifyEngineTime(seconds);
            }
        }];
    }
}

- (void)loadURL:(NSURL *)url {
    [self cleanupCurrentItemObservers];

    _coordinator->notifyEngineState(PlayerCore::PlaybackState::Loading);

    // Create item with injected headers, ResourceLoader interceptor, and FairPlay DRM session
    AVPlayerItem *item = [self.networkAuthManager createPlayerItemForURL:url];
    [self attachItemObservers:item];

    if (!self.player) {
        AVPlayer *newPlayer = [AVPlayer playerWithPlayerItem:item];
        [self attachPlayer:newPlayer];
    } else {
        [self.player replaceCurrentItemWithPlayerItem:item];
    }
}

- (void)attachItemObservers:(AVPlayerItem *)item {
    if (!item) { return; }

    [item addObserver:self
           forKeyPath:@"status"
              options:NSKeyValueObservingOptionNew
              context:AVPlayerAdapterKVOContext];

    [item addObserver:self
           forKeyPath:@"loadedTimeRanges"
              options:NSKeyValueObservingOptionNew
              context:AVPlayerAdapterKVOContext];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
    _isObservingItem = YES;
}

- (void)cleanupCurrentItemObservers {
    if (_isObservingItem && self.player.currentItem) {
        @try {
            [self.player.currentItem removeObserver:self forKeyPath:@"status" context:AVPlayerAdapterKVOContext];
            [self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:AVPlayerAdapterKVOContext];
        } @catch (NSException *exception) {
            // Observer was not registered
        }
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.player.currentItem];
        _isObservingItem = NO;
    }
}

- (void)detachPlayer {
    [self cleanupCurrentItemObservers];

    if (_isObservingPlayer && self.player) {
        @try {
            [self.player removeObserver:self forKeyPath:@"timeControlStatus" context:AVPlayerAdapterKVOContext];
        } @catch (NSException *exception) {
            // Observer was not registered
        }
        _isObservingPlayer = NO;
    }

    if (self.timeObserverToken && self.player) {
        [self.player removeTimeObserver:self.timeObserverToken];
        self.timeObserverToken = nil;
    }

    _bridge->setPlayer(nil);
    self.player = nil;
}

#pragma mark - KVO & Notifications

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if (context != AVPlayerAdapterKVOContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    if (!_coordinator) { return; }

    // 1. Time Control Status (Play / Pause / Buffering)
    if ([keyPath isEqualToString:@"timeControlStatus"]) {
        AVPlayerTimeControlStatus status = (AVPlayerTimeControlStatus)[change[NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            case AVPlayerTimeControlStatusPaused:
                _coordinator->notifyEngineState(PlayerCore::PlaybackState::Paused);
                break;
            case AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate:
                _coordinator->notifyEngineState(PlayerCore::PlaybackState::Buffering);
                break;
            case AVPlayerTimeControlStatusPlaying:
                _coordinator->notifyEngineState(PlayerCore::PlaybackState::Playing);
                break;
        }
    }
    // 2. Player Item Status (Ready to play or Error)
    else if ([keyPath isEqualToString:@"status"]) {
        AVPlayerItemStatus status = (AVPlayerItemStatus)[change[NSKeyValueChangeNewKey] integerValue];
        if (status == AVPlayerItemStatusReadyToPlay) {
            _coordinator->notifyEngineState(PlayerCore::PlaybackState::Ready);
            double duration = CMTimeGetSeconds(self.player.currentItem.duration);
            if (!isnan(duration) && duration > 0.0) {
                _coordinator->notifyEngineDuration(duration);
            }
        } else if (status == AVPlayerItemStatusFailed) {
            NSError *error = self.player.currentItem.error;
            std::string msg = error ? error.localizedDescription.UTF8String : "Media item failed to load";
            int code = error ? (int)error.code : -1;
            _coordinator->notifyEngineError(code, msg);
        }
    }
    // 3. Loaded Time Ranges (Buffering Progress)
    else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        NSArray *timeRanges = self.player.currentItem.loadedTimeRanges;
        if (timeRanges.count > 0) {
            CMTimeRange timeRange = [timeRanges.firstObject CMTimeRangeValue];
            double startSeconds = CMTimeGetSeconds(timeRange.start);
            double durationSeconds = CMTimeGetSeconds(timeRange.duration);
            double bufferedTime = startSeconds + durationSeconds;
            if (!isnan(bufferedTime)) {
                _coordinator->notifyEngineBuffer(bufferedTime);
            }
        }
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    if (_coordinator) {
        _coordinator->notifyEngineState(PlayerCore::PlaybackState::Ended);
    }
}

- (void)cleanup {
    [self detachPlayer];
    if (_coordinator) {
        _coordinator->setEngineBridge(nullptr);
        _coordinator = nullptr;
    }
    _bridge = nullptr;
}

- (void)dealloc {
    [self cleanup];
}

@end
