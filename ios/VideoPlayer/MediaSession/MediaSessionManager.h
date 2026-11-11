//
//  MediaSessionManager.h
//  Player
//
//  Created by Antigravity on 11/11/26.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MediaSessionManagerDelegate <NSObject>
- (void)mediaSessionDidRequestPlay;
- (void)mediaSessionDidRequestPause;
- (void)mediaSessionDidRequestTogglePlayPause;
- (void)mediaSessionDidRequestSeekTo:(NSTimeInterval)time;
- (void)mediaSessionDidRequestSkipForward:(NSTimeInterval)interval;
- (void)mediaSessionDidRequestSkipBackward:(NSTimeInterval)interval;
@end

@interface MediaSessionManager : NSObject

@property (nonatomic, weak, nullable) id<MediaSessionManagerDelegate> delegate;

- (void)setupRemoteCommandsWithSkipInterval:(NSTimeInterval)interval;
- (void)updateNowPlayingInfoWithTitle:(NSString *)title
                          currentTime:(NSTimeInterval)currentTime
                             duration:(NSTimeInterval)duration
                         playbackRate:(float)rate;
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
