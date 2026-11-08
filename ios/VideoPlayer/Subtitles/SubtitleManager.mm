//
//  SubtitleManager.mm
//  Player
//
//  Dedicated Subtitle / Closed-Caption manager implementation for iOS & tvOS.
//

#import "SubtitleManager.h"

@implementation SubtitleTrack

- (instancetype)initWithIdentifier:(NSString *)identifier
                          language:(NSString *)language
                             label:(NSString *)label
                        isSelected:(BOOL)isSelected {
    self = [super init];
    if (self) {
        _identifier = [identifier copy];
        _language = [language copy];
        _label = [label copy];
        _isSelected = isSelected;
    }
    return self;
}

@end

@interface SubtitleManager ()
@property (nonatomic, weak, nullable) AVPlayerItem *playerItem;
@property (nonatomic, copy, readwrite) NSArray<SubtitleTrack *> *availableTracks;
@property (nonatomic, strong, readwrite, nullable) SubtitleTrack *activeTrack;
@end

@implementation SubtitleManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _availableTracks = @[];
    }
    return self;
}

- (void)attachPlayerItem:(nullable AVPlayerItem *)item {
    self.playerItem = item;
    [self refreshTracks];
}

- (void)refreshTracks {
    if (!self.playerItem || !self.playerItem.asset) {
        self.availableTracks = @[];
        self.activeTrack = nil;
        [self.delegate subtitleManager:self didUpdateSubtitles:@[] activeSubtitle:nil];
        return;
    }

    AVAsset *asset = self.playerItem.asset;
    AVMediaSelectionGroup *legibleGroup = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
    if (!legibleGroup || legibleGroup.options.count == 0) {
        self.availableTracks = @[];
        self.activeTrack = nil;
        [self.delegate subtitleManager:self didUpdateSubtitles:@[] activeSubtitle:nil];
        return;
    }

    AVMediaSelectionOption *selectedOption = [self.playerItem.currentMediaSelection selectedMediaOptionInMediaSelectionGroup:legibleGroup];

    NSMutableArray<SubtitleTrack *> *tracks = [NSMutableArray array];
    SubtitleTrack *currentActive = nil;

    for (NSUInteger i = 0; i < legibleGroup.options.count; i++) {
        AVMediaSelectionOption *option = legibleGroup.options[i];
        NSString *lang = [option.locale objectForKey:NSLocaleLanguageCode] ?: @"und";
        NSString *label = option.displayName ?: [NSString stringWithFormat:@"Subtitle %lu", (unsigned long)(i + 1)];
        BOOL isSelected = [selectedOption isEqual:option];

        SubtitleTrack *track = [[SubtitleTrack alloc] initWithIdentifier:[NSString stringWithFormat:@"%@-%lu", lang, (unsigned long)i]
                                                                language:lang
                                                                   label:label
                                                              isSelected:isSelected];
        [tracks addObject:track];
        if (isSelected) {
            currentActive = track;
        }
    }

    self.availableTracks = [tracks copy];
    self.activeTrack = currentActive;

    [self.delegate subtitleManager:self didUpdateSubtitles:self.availableTracks activeSubtitle:self.activeTrack];
}

- (void)selectLanguage:(nullable NSString *)languageCode {
    if (!self.playerItem || !self.playerItem.asset) { return; }

    AVAsset *asset = self.playerItem.asset;
    AVMediaSelectionGroup *legibleGroup = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
    if (!legibleGroup) { return; }

    if (!languageCode || languageCode.length == 0) {
        [self.playerItem selectMediaOption:nil inMediaSelectionGroup:legibleGroup];
    } else {
        AVMediaSelectionOption *matched = nil;
        for (AVMediaSelectionOption *option in legibleGroup.options) {
            NSString *lang = [option.locale objectForKey:NSLocaleLanguageCode];
            if ([lang isEqualToString:languageCode]) {
                matched = option;
                break;
            }
        }
        if (matched) {
            [self.playerItem selectMediaOption:matched inMediaSelectionGroup:legibleGroup];
        }
    }

    [self refreshTracks];
}

- (BOOL)toggleSubtitles {
    if (self.availableTracks.count == 0) { return NO; }

    if (self.activeTrack != nil) {
        [self selectLanguage:nil];
        return NO;
    } else {
        NSString *targetLang = self.availableTracks.firstObject.language ?: @"en";
        [self selectLanguage:targetLang];
        return YES;
    }
}

@end
