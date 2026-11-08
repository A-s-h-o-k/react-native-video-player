//
//  AVPlayerAdapter.mm
//  Player
//
//  Bridge adapter connecting AVPlayer to PlayerStateCoordinator.
//

#import "AVPlayerAdapter.h"
#import "../Network/NetworkAuthManager.h"
#import "../../../cpp/IPlaybackEngineBridge.hpp"

static void *AVPlayerAdapterKVOContext = &AVPlayerAdapterKVOContext;

#pragma mark - C++ Engine Bridge Implementation

struct AVPlayerAdapterBridge : public PlayerCore::IPlaybackEngineBridge {
    __weak AVPlayerAdapter *adapter;

    AVPlayerAdapterBridge(AVPlayerAdapter *a = nil) : adapter(a) {}

    void executePlay() override {
        dispatch_async(dispatch_get_main_queue(), ^{
            [adapter.player play];
        });
    }

    void executePause() override {
        dispatch_async(dispatch_get_main_queue(), ^{
            [adapter.player pause];
        });
    }

    void executeSeek(double seconds) override {
        dispatch_async(dispatch_get_main_queue(), ^{
            CMTime target = CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC);
            [adapter.player seekToTime:target toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        });
    }

    void executePlaybackRate(float rate) override {
        dispatch_async(dispatch_get_main_queue(), ^{
            adapter.player.rate = rate;
        });
    }

    void executeVolume(float volume) override {
        dispatch_async(dispatch_get_main_queue(), ^{
            adapter.player.volume = volume;
        });
    }

    void executeMute(bool muted) override {
        dispatch_async(dispatch_get_main_queue(), ^{
            adapter.player.muted = muted;
        });
    }
};

#pragma mark - Objective-C++ Adapter Implementation

@interface AVPlayerAdapter () <AVPlayerItemMetadataOutputPushDelegate> {
    PlayerCore::PlayerStateCoordinator *_coordinator;
    AVPlayerAdapterBridge _bridge;
}
@property (nonatomic, strong, readwrite, nullable) AVPlayer *player;
@property (nonatomic, strong, readwrite) NetworkAuthManager *networkAuthManager;
@property (nonatomic, strong, nullable) AVPlayerItem *observedItem;
@property (nonatomic, strong, nullable) AVPlayerItemMetadataOutput *metadataOutput;
@property (nonatomic, strong, nullable) id timeObserverToken;
@property (nonatomic, assign) BOOL isObservingItem;
@property (nonatomic, assign) BOOL isObservingPlayer;
@property (nonatomic, assign) BOOL isCleanedUp;
@property (nonatomic, assign) NSTimeInterval lastReportedBufferTime;
@end

@implementation AVPlayerAdapter

- (instancetype)initWithCoordinator:(PlayerCore::PlayerStateCoordinator *)coordinator {
    self = [super init];
    if (self) {
        _coordinator = coordinator;
        _bridge = AVPlayerAdapterBridge(self);
        _coordinator->setEngineBridge(&_bridge);
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

    if (!self.player) {
        AVPlayer *newPlayer = [AVPlayer playerWithPlayerItem:item];
        [self attachPlayer:newPlayer];
    } else {
        [self.player replaceCurrentItemWithPlayerItem:item];
    }

    [self attachItemObservers:item];
}

- (void)attachItemObservers:(AVPlayerItem *)item {
    if (!item) { return; }
    [self cleanupCurrentItemObservers];
    self.observedItem = item;
    _lastReportedBufferTime = -1.0;

    // Cap forward buffer to 30.0s to prevent runaway memory and cellular data usage
    item.preferredForwardBufferDuration = 30.0;

    // Configure low-latency live streaming offset
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        item.automaticallyPreservesTimeOffsetFromLive = YES;
        item.configuredTimeOffsetFromLive = CMTimeMakeWithSeconds(2.0, NSEC_PER_SEC);
    }

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

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemNewAccessLogEntry:)
                                                 name:AVPlayerItemNewAccessLogEntryNotification
                                               object:item];

    // Configure in-stream timed metadata output (ID3, SCTE-35, chapters)
    AVPlayerItemMetadataOutput *metadataOutput = [[AVPlayerItemMetadataOutput alloc] init];
    [metadataOutput setDelegate:self queue:dispatch_get_main_queue()];
    [item addOutput:metadataOutput];
    self.metadataOutput = metadataOutput;

    _isObservingItem = YES;
}

- (void)cleanupCurrentItemObservers {
    if (_isObservingItem && self.observedItem) {
        @try {
            [self.observedItem removeObserver:self forKeyPath:@"status" context:AVPlayerAdapterKVOContext];
            [self.observedItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:AVPlayerAdapterKVOContext];
        } @catch (NSException *exception) {
            // Observer was not registered
        }
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.observedItem];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemNewAccessLogEntryNotification
                                                      object:self.observedItem];

        if (self.metadataOutput) {
            [self.metadataOutput setDelegate:nil queue:nil];
            [self.observedItem removeOutput:self.metadataOutput];
            self.metadataOutput = nil;
        }

        self.observedItem = nil;
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

    if (self.player) {
        [self.player pause];
    }
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
            case AVPlayerTimeControlStatusPaused: {
                if (_coordinator && _coordinator->getSnapshot().state == PlayerCore::PlaybackState::Ended) {
                    return;
                }
                AVPlayerItem *currentItem = self.player.currentItem;
                if (currentItem) {
                    double currentSecs = CMTimeGetSeconds(self.player.currentTime);
                    double durationSecs = CMTimeGetSeconds(currentItem.duration);
                    if (!isnan(currentSecs) && !isnan(durationSecs) && durationSecs > 0.0 && currentSecs >= (durationSecs - 0.35)) {
                        _coordinator->notifyEngineState(PlayerCore::PlaybackState::Ended);
                        return;
                    }
                }
                _coordinator->notifyEngineState(PlayerCore::PlaybackState::Paused);
                break;
            }
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
            if (self.onItemReadyToPlay && self.player.currentItem) {
                self.onItemReadyToPlay(self.player.currentItem);
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
            double currentTime = CMTimeGetSeconds(self.player.currentTime);
            double bufferedTime = 0.0;
            for (NSValue *rangeValue in timeRanges) {
                CMTimeRange timeRange = [rangeValue CMTimeRangeValue];
                double startSeconds = CMTimeGetSeconds(timeRange.start);
                double durationSeconds = CMTimeGetSeconds(timeRange.duration);
                double endSeconds = startSeconds + durationSeconds;
                if (!isnan(startSeconds) && !isnan(durationSeconds)) {
                    if (currentTime >= startSeconds && currentTime <= endSeconds) {
                        bufferedTime = endSeconds;
                        break;
                    } else if (endSeconds > bufferedTime) {
                        bufferedTime = endSeconds;
                    }
                }
            }
            if (!isnan(bufferedTime)) {
                double duration = CMTimeGetSeconds(self.player.currentItem.duration);
                BOOL isCompleted = (!isnan(duration) && duration > 0.0 && bufferedTime >= (duration - 0.25));
                if (fabs(bufferedTime - _lastReportedBufferTime) >= 0.5 || isCompleted) {
                    _lastReportedBufferTime = bufferedTime;
                    _coordinator->notifyEngineBuffer(bufferedTime);
                }
            }
        }
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification {
    if (notification.object && self.player.currentItem && notification.object != self.player.currentItem) {
        return;
    }
    if (_coordinator) {
        _coordinator->notifyEngineState(PlayerCore::PlaybackState::Ended);
    }
}

- (void)playerItemNewAccessLogEntry:(NSNotification *)notification {
    AVPlayerItem *item = (AVPlayerItem *)notification.object;
    if (!item || item != self.observedItem || !_coordinator) { return; }
    AVPlayerItemAccessLogEvent *lastEvent = item.accessLog.events.lastObject;
    if (lastEvent) {
        double rttMs = lastEvent.transferDuration * 1000.0; // transfer duration in milliseconds
        double bitrateBps = lastEvent.observedBitrate;       // measured bandwidth in bits per second
        if (!isnan(rttMs) && rttMs >= 0.0 && !isnan(bitrateBps) && bitrateBps >= 0.0) {
            _coordinator->notifyEngineNetworkMetrics(rttMs, bitrateBps);
        }
    }
}

#pragma mark - AVPlayerItemMetadataOutputPushDelegate

- (void)metadataOutput:(AVPlayerItemMetadataOutput *)output
didOutputTimedMetadataGroups:(NSArray<AVTimedMetadataGroup *> *)groups
  fromPlayerItemTrack:(AVPlayerItemTrack *)track {
    // In-stream parsed timed metadata available as playhead advances
}

- (void)cleanup {
    if (_isCleanedUp) {
        return;
    }
    _isCleanedUp = YES;

    [self detachPlayer];
    if (_coordinator) {
        _coordinator->setEngineBridge(nullptr);
        _coordinator = nullptr;
    }
}

- (void)dealloc {
    [self cleanup];
}

@end
