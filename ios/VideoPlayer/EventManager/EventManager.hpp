//
//  EventManager.h
//  Player
//
//  Created by Ashok Ammineni on 20/12/25.
//

#ifndef EventManager_h
#define EventManager_h
//
//#import <Foundation/Foundation.h>
//#import <AVFoundation/AVFoundation.h>
//#import "../Layers/ControlLayer/ControlLayer.mm"

//@interface EventManager : NSObject
//
//// state variables
//@property (nonatomic, assign) BOOL isPlaying;
//@property (nonatomic, assign) BOOL isBuffering;
//@property (nonatomic, assign) NSNumber * currentPlayTime;
//@property (nonatomic, strong) AVPlayerLayer *playerLayer;
//@property (nonatomic, strong) AVPlayer *videoPlayer;

//@property (nonatomic, strong) ControlLayer * controlLayer;

//- (void)emitEvent:(NSString *)type;


//@end

#endif /* EventManager_h */

#import <iostream>

class PlayerManager {

  
  
public:
  
  // variables
  bool isPlaying;
  bool isBuffering;
  int playbackTime;
  std::string videoUrl;
  
};
