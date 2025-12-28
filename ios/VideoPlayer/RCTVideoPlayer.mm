//
//  RCTVideoPlayer.m
//  Player
//
//  Created by Ashok Ammineni on 16/12/25.
//

#import <Foundation/Foundation.h>

#import "RCTVideoPlayer.h"

#import <AVFoundation/AVFoundation.h>
#import <React/RCTLog.h>
#import <React/RCTUIManager.h>
#import "ControlLayer.h"



#pragma mark - Native View

@interface RCTVideoPlayerView : UIView

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) ControlLayer * controlsLayer;
//@property (nonatomic, strong) A

/** matches: sourceURL?: string */
@property (nonatomic, copy) NSString *sourceURL;

/** matches: onScriptLoaded?: BubblingEventHandler */
@property (nonatomic, copy) RCTBubblingEventBlock onScriptLoaded;

@property (nonatomic, assign) BOOL play;

@end

@implementation RCTVideoPlayerView

- (instancetype)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = UIColor.blackColor;
  }
  return self;
}

#pragma mark - Prop Setter

- (void)setSourceURL:(NSString *)sourceURL
{
  if (_sourceURL && [_sourceURL isEqualToString:sourceURL]) {
    return;
  }

  _sourceURL = [sourceURL copy];

  if (!_sourceURL || _sourceURL.length == 0) {
    return;
  }

  NSURL *url = [NSURL URLWithString:_sourceURL];
  if (!url) {
    RCTLogError(@"[VideoPlayer] Invalid URL: %@", _sourceURL);
    [self emitResult:@"error"];
    return;
  }

  [self loadVideo:url];
}

#pragma mark - Player

- (void)loadVideo:(NSURL *)url
{
  [self cleanup];

  AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
  self.player = [AVPlayer playerWithPlayerItem:item];

  self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
  self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
  self.controlsLayer = [[ControlLayer alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
  [self.controlsLayer setVideoPlayer:self.player];
  self.controlsLayer.opaque = YES;
  [self.layer addSublayer:self.playerLayer];
  [self addSubview: self.controlsLayer];
  self.playerLayer.zPosition = 0;
  self.controlsLayer.layer.zPosition = 1;
  [self.player play];
  [self emitResult:@"success"];
}

#pragma mark - Event

- (void)emitResult:(NSString *)result
{
  if (self.onScriptLoaded) {
    self.onScriptLoaded(@{
      @"result": result
    });
  }
}

#pragma mark - Layout

- (void)layoutSubviews
{
  [super layoutSubviews];
  self.playerLayer.frame = self.bounds;
  self.controlsLayer.frame = self.bounds;
}

#pragma mark - Cleanup

- (void)cleanup
{
  if (self.player) {
    [self.player pause];
    [self.playerLayer removeFromSuperlayer];
    self.player = nil;
    self.playerLayer = nil;
  }
}

- (void)dealloc
{
  [self cleanup];
}

@end

#pragma mark - View Manager

@implementation RCTVideoPlayer

RCT_EXPORT_MODULE(VideoPlayer)

- (UIView *)view
{
  return [[RCTVideoPlayerView alloc] init];
}

/** sourceURL?: string */
RCT_EXPORT_VIEW_PROPERTY(sourceURL, NSString)

/** onScriptLoaded?: BubblingEventHandler<{ result }> */
RCT_EXPORT_VIEW_PROPERTY(onScriptLoaded, RCTBubblingEventBlock)

@end
