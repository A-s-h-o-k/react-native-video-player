//
//  EventManager.h
//  Player
//
//  Created by Ashok Ammineni on 20/12/25.
//

#ifndef EventManager_h
#define EventManager_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface EventManager : NSObject

@property (nonatomic, strong) AVPlayerLayer*player;

-(NSObject*) emitEvent: type;




@end

#endif /* EventManager_h */
