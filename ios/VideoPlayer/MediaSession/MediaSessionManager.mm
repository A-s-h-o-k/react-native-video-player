//
//  MediaSessionManager.mm
//  Player
//
//  Created by Antigravity on 11/11/26.
//

#import "MediaSessionManager.h"

@interface MediaSessionManager ()
@property (nonatomic, assign) NSTimeInterval skipInterval;
@end

@implementation MediaSessionManager

- (instancetype)init {
  self = [super init];
  if (self) {
    _skipInterval = 15.0;
  }
  return self;
}

- (void)setupRemoteCommandsWithSkipInterval:(NSTimeInterval)interval {
  self.skipInterval = interval > 0 ? interval : 15.0;
  MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
  
  [self removeCommandTargets];
  
  commandCenter.playCommand.enabled = YES;
  [commandCenter.playCommand addTarget:self action:@selector(handlePlayCommand:)];
  
  commandCenter.pauseCommand.enabled = YES;
  [commandCenter.pauseCommand addTarget:self action:@selector(handlePauseCommand:)];
  
  commandCenter.togglePlayPauseCommand.enabled = YES;
  [commandCenter.togglePlayPauseCommand addTarget:self action:@selector(handleTogglePlayPauseCommand:)];
  
  commandCenter.changePlaybackPositionCommand.enabled = YES;
  [commandCenter.changePlaybackPositionCommand addTarget:self action:@selector(handleChangePlaybackPositionCommand:)];
  
  commandCenter.skipForwardCommand.enabled = YES;
  commandCenter.skipForwardCommand.preferredIntervals = @[@(self.skipInterval)];
  [commandCenter.skipForwardCommand addTarget:self action:@selector(handleSkipForwardCommand:)];
  
  commandCenter.skipBackwardCommand.enabled = YES;
  commandCenter.skipBackwardCommand.preferredIntervals = @[@(self.skipInterval)];
  [commandCenter.skipBackwardCommand addTarget:self action:@selector(handleSkipBackwardCommand:)];
}

- (void)removeCommandTargets {
  MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
  [commandCenter.playCommand removeTarget:self];
  [commandCenter.pauseCommand removeTarget:self];
  [commandCenter.togglePlayPauseCommand removeTarget:self];
  [commandCenter.changePlaybackPositionCommand removeTarget:self];
  [commandCenter.skipForwardCommand removeTarget:self];
  [commandCenter.skipBackwardCommand removeTarget:self];
  
  commandCenter.playCommand.enabled = NO;
  commandCenter.pauseCommand.enabled = NO;
  commandCenter.togglePlayPauseCommand.enabled = NO;
  commandCenter.changePlaybackPositionCommand.enabled = NO;
  commandCenter.skipForwardCommand.enabled = NO;
  commandCenter.skipBackwardCommand.enabled = NO;
}

- (MPRemoteCommandHandlerStatus)handlePlayCommand:(MPRemoteCommandEvent *)event {
  if ([self.delegate respondsToSelector:@selector(mediaSessionDidRequestPlay)]) {
    [self.delegate mediaSessionDidRequestPlay];
    return MPRemoteCommandHandlerStatusSuccess;
  }
  return MPRemoteCommandHandlerStatusCommandFailed;
}

- (MPRemoteCommandHandlerStatus)handlePauseCommand:(MPRemoteCommandEvent *)event {
  if ([self.delegate respondsToSelector:@selector(mediaSessionDidRequestPause)]) {
    [self.delegate mediaSessionDidRequestPause];
    return MPRemoteCommandHandlerStatusSuccess;
  }
  return MPRemoteCommandHandlerStatusCommandFailed;
}

- (MPRemoteCommandHandlerStatus)handleTogglePlayPauseCommand:(MPRemoteCommandEvent *)event {
  if ([self.delegate respondsToSelector:@selector(mediaSessionDidRequestTogglePlayPause)]) {
    [self.delegate mediaSessionDidRequestTogglePlayPause];
    return MPRemoteCommandHandlerStatusSuccess;
  }
  return MPRemoteCommandHandlerStatusCommandFailed;
}

- (MPRemoteCommandHandlerStatus)handleChangePlaybackPositionCommand:(MPChangePlaybackPositionCommandEvent *)event {
  if ([self.delegate respondsToSelector:@selector(mediaSessionDidRequestSeekTo:)]) {
    [self.delegate mediaSessionDidRequestSeekTo:event.positionTime];
    return MPRemoteCommandHandlerStatusSuccess;
  }
  return MPRemoteCommandHandlerStatusCommandFailed;
}

- (MPRemoteCommandHandlerStatus)handleSkipForwardCommand:(MPSkipIntervalCommandEvent *)event {
  if ([self.delegate respondsToSelector:@selector(mediaSessionDidRequestSkipForward:)]) {
    NSTimeInterval interval = event.interval > 0 ? event.interval : self.skipInterval;
    [self.delegate mediaSessionDidRequestSkipForward:interval];
    return MPRemoteCommandHandlerStatusSuccess;
  }
  return MPRemoteCommandHandlerStatusCommandFailed;
}

- (MPRemoteCommandHandlerStatus)handleSkipBackwardCommand:(MPSkipIntervalCommandEvent *)event {
  if ([self.delegate respondsToSelector:@selector(mediaSessionDidRequestSkipBackward:)]) {
    NSTimeInterval interval = event.interval > 0 ? event.interval : self.skipInterval;
    [self.delegate mediaSessionDidRequestSkipBackward:interval];
    return MPRemoteCommandHandlerStatusSuccess;
  }
  return MPRemoteCommandHandlerStatusCommandFailed;
}

- (void)updateNowPlayingInfoWithTitle:(NSString *)title
                          currentTime:(NSTimeInterval)currentTime
                             duration:(NSTimeInterval)duration
                         playbackRate:(float)rate {
  NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary dictionary];
  if (title.length > 0) {
    nowPlayingInfo[MPMediaItemPropertyTitle] = title;
  }
  if (duration > 0 && !isnan(duration)) {
    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = @(duration);
  }
  if (!isnan(currentTime) && currentTime >= 0) {
    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(currentTime);
  }
  nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = @(rate);
  
  [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nowPlayingInfo;
}

- (void)cleanup {
  [self removeCommandTargets];
  [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
  self.delegate = nil;
}

- (void)dealloc {
  [self cleanup];
}

@end
