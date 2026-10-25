//
//  EventManager.m
//  Player
//
//  Created by Ashok Ammineni on 27/12/25.
//



#include "stdio.h"
#include <iostream>

class EventManager {
  bool isPlaying = false;
  bool onMute = false;
  std::string currentPlayingUrl = "";
  
  
public:
  void onPressPlayPause(bool play)  {
    if(play) {
      this->isPlaying = true;
    } else {
      this -> isPlaying = false;
    }
  }
  
  void playBackDispatch(bool play) {
    if(this->isPlaying) {
        
    }
  }
  
  
  
  
  
  
  
};







