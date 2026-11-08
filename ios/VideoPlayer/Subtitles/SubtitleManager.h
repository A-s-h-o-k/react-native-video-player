//
//  SubtitleManager.h
//  Player
//
//  Dedicated Subtitle / Closed-Caption manager for iOS & tvOS.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SubtitleTrack : NSObject

@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *language;
@property (nonatomic, copy, readonly) NSString *label;
@property (nonatomic, assign, readonly) BOOL isSelected;

- (instancetype)initWithIdentifier:(NSString *)identifier
                          language:(NSString *)language
                             label:(NSString *)label
                        isSelected:(BOOL)isSelected;

@end

@class SubtitleManager;

@protocol SubtitleManagerDelegate <NSObject>
- (void)subtitleManager:(SubtitleManager *)manager
     didUpdateSubtitles:(NSArray<SubtitleTrack *> *)subtitles
         activeSubtitle:(nullable SubtitleTrack *)activeSubtitle;
@end

@interface SubtitleManager : NSObject

@property (nonatomic, weak, nullable) id<SubtitleManagerDelegate> delegate;
@property (nonatomic, copy, readonly) NSArray<SubtitleTrack *> *availableTracks;
@property (nonatomic, strong, readonly, nullable) SubtitleTrack *activeTrack;

- (void)attachPlayerItem:(nullable AVPlayerItem *)item;
- (void)selectLanguage:(nullable NSString *)languageCode;
- (BOOL)toggleSubtitles;

@end

NS_ASSUME_NONNULL_END
