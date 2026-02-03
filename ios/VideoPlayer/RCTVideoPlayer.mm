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

/** matches: videoUrl?: string */
@property (nonatomic, copy) NSString *videoUrl;

/** matches: onScriptLoaded?: BubblingEventHandler */
@property (nonatomic, copy) RCTBubblingEventBlock onScriptLoaded;

@property (nonatomic, assign) BOOL play;

@end

@implementation RCTVideoPlayerView

- (instancetype)initWithFrame:(CGRect)frame
{
  NSLog(@"calling initWithFrame");
  if ((self = [super initWithFrame:frame])) {
    self.backgroundColor = UIColor.blackColor;
  }

  return self;
}

#pragma mark - Prop Setter

- (void)setVideoUrl:(NSString *)videoUrl
{
   NSLog(@"calling setVideoUrl:");
  if (_videoUrl && [_videoUrl isEqualToString:videoUrl]) {
    return;
  }

  _videoUrl = [videoUrl copy];

  if (!_videoUrl || _videoUrl.length == 0) {
    return;
  }

  NSURL *url = [NSURL URLWithString:_videoUrl];
  if (!url) {
    RCTLogError(@"[VideoPlayer] Invalid URL:");
    [self emitResult:@"error"];
    return;
  }

  [self loadVideo:url];
}

- (void)setPlay:(BOOL)play
{
  NSLog(@"calling setPlay");
  if (_play == play) {
    return;
  }
  _play = play;

  if (self.player) {
    if (_play) {
      [self.player play];
    } else {
      [self.player pause];
    }
  }
}
#pragma mark - Player

- (void)loadVideo:(NSURL *)url
{
  NSLog(@"calling loadVideo:");
  [self cleanup];

  AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
  self.player = [AVPlayer playerWithPlayerItem:item];

  self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
  self.playerLayer.videoGravity = AVLayerVideoGravityResize; // Match Android's RESIZE_MODE_FIT
  self.controlsLayer = [[ControlLayer alloc] initWithFrame:self.frame]; // Initialize without a hardcoded frame
  [self.controlsLayer setVideoPlayer:self.player];
  self.controlsLayer.opaque = YES;
  [self.layer addSublayer:self.playerLayer];
  [self addSubview: self.controlsLayer];
  // setting the constraint for control layer to take the height width as parent
  [NSLayoutConstraint activateConstraints:@[
    [self.controlsLayer.trailingAnchor  constraintEqualToAnchor :  self.trailingAnchor],
    [self.controlsLayer.leadingAnchor constraintEqualToAnchor : self.leadingAnchor],
    [self.controlsLayer.topAnchor constraintEqualToAnchor: self.topAnchor],
    [self.controlsLayer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor]
  ]];
  self.playerLayer.zPosition = 0;
  self.controlsLayer.layer.zPosition = 1;
  if (self.play) {
    [self.player play];
  }
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
  NSLog(@"calling layoutSubviews");
  [super layoutSubviews];
  self.playerLayer.frame = self.bounds;
  
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

/** videoUrl?: string */
RCT_EXPORT_VIEW_PROPERTY(videoUrl, NSString)

/** onScriptLoaded?: BubblingEventHandler<{ result }> */
RCT_EXPORT_VIEW_PROPERTY(onScriptLoaded, RCTBubblingEventBlock)

/** play?: boolean */
RCT_EXPORT_VIEW_PROPERTY(play, BOOL)

@end
