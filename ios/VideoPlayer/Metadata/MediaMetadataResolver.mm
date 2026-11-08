//
//  MediaMetadataResolver.mm
//  Player
//
//  Dedicated metadata resolver implementation for iOS & tvOS.
//

#import "MediaMetadataResolver.h"

@implementation MediaMetadataInfo

- (instancetype)initWithTitle:(NSString *)title
                       artist:(nullable NSString *)artist
                  artworkData:(nullable NSData *)artworkData {
    self = [super init];
    if (self) {
        _title = [title copy] ?: @"";
        _artist = [artist copy];
        _artworkData = artworkData;
    }
    return self;
}

@end

@implementation MediaMetadataResolver

- (MediaMetadataInfo *)resolveWithExplicitTitle:(nullable NSString *)explicitTitle
                                     playerItem:(nullable AVPlayerItem *)playerItem
                                            url:(nullable NSURL *)url {
    NSString *trimmedExplicit = [explicitTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmedExplicit.length > 0) {
        return [[MediaMetadataInfo alloc] initWithTitle:trimmedExplicit artist:nil artworkData:nil];
    }

    NSString *embeddedTitle = nil;
    NSString *embeddedArtist = nil;
    NSData *artworkData = nil;

    if (playerItem && playerItem.asset) {
        AVAsset *asset = playerItem.asset;
        NSArray<AVMetadataItem *> *common = asset.commonMetadata;

        // 1. Resolve Title
        NSArray<AVMetadataItem *> *titleItems = [AVMetadataItem metadataItemsFromArray:common
                                                                               withKey:AVMetadataCommonKeyTitle
                                                                              keySpace:AVMetadataKeySpaceCommon];
        if (titleItems.count == 0) {
            titleItems = [AVMetadataItem metadataItemsFromArray:asset.metadata
                                                        withKey:AVMetadataQuickTimeMetadataKeyTitle
                                                       keySpace:AVMetadataKeySpaceQuickTimeMetadata];
        }
        if (titleItems.count > 0) {
            embeddedTitle = [titleItems.firstObject.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }

        // 2. Resolve Artist
        NSArray<AVMetadataItem *> *artistItems = [AVMetadataItem metadataItemsFromArray:common
                                                                                withKey:AVMetadataCommonKeyArtist
                                                                               keySpace:AVMetadataKeySpaceCommon];
        if (artistItems.count > 0) {
            embeddedArtist = [artistItems.firstObject.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }

        // 3. Resolve Artwork
        NSArray<AVMetadataItem *> *artworkItems = [AVMetadataItem metadataItemsFromArray:common
                                                                                withKey:AVMetadataCommonKeyArtwork
                                                                               keySpace:AVMetadataKeySpaceCommon];
        if (artworkItems.count > 0) {
            artworkData = artworkItems.firstObject.dataValue;
        }
    }

    NSString *finalTitle = (embeddedTitle.length > 0) ? embeddedTitle : [self deriveTitleFromURL:url];

    return [[MediaMetadataInfo alloc] initWithTitle:finalTitle artist:embeddedArtist artworkData:artworkData];
}

- (NSString *)deriveTitleFromURL:(nullable NSURL *)url {
    if (!url) { return @""; }

    NSString *lastComponent = [url lastPathComponent];
    if (!lastComponent || lastComponent.length == 0) { return @""; }

    // 1. Decode URL percent encoding
    NSString *decoded = [lastComponent stringByRemovingPercentEncoding] ?: lastComponent;

    // 2. Strip standard media extensions
    NSArray<NSString *> *extensions = @[@".mp4", @".m4v", @".mov", @".mkv", @".webm",
                                        @".m3u8", @".mpd", @".ts", @".flv", @".3gp", @".avi", @".wmv"];
    for (NSString *ext in extensions) {
        if ([decoded.lowercaseString hasSuffix:ext]) {
            decoded = [decoded substringToIndex:(decoded.length - ext.length)];
            break;
        }
    }

    // 3. Strip quality & codec tokens
    NSError *error = nil;
    NSRegularExpression *tagRegex = [NSRegularExpression regularExpressionWithPattern:@"(?i)[\\[(_-]*(1080p|720p|480p|2160p|4k|h264|h265|hevc|aac|x264|x265|bluray|webrip)[\\])_-]*"
                                                                              options:0
                                                                                error:&error];
    if (!error && tagRegex) {
        decoded = [tagRegex stringByReplacingMatchesInString:decoded
                                                     options:0
                                                       range:NSMakeRange(0, decoded.length)
                                                withTemplate:@" "];
    }

    // 4. Expand CamelCase: "BigBuckBunny" -> "Big Buck Bunny"
    NSRegularExpression *camelRegex = [NSRegularExpression regularExpressionWithPattern:@"(?<=[a-z])(?=[A-Z])"
                                                                                options:0
                                                                                  error:&error];
    if (!error && camelRegex) {
        decoded = [camelRegex stringByReplacingMatchesInString:decoded
                                                       options:0
                                                         range:NSMakeRange(0, decoded.length)
                                                  withTemplate:@" "];
    }

    // 5. Replace separators (_, -, .) with spaces
    NSRegularExpression *delimRegex = [NSRegularExpression regularExpressionWithPattern:@"[_\\-.]+"
                                                                                options:0
                                                                                  error:&error];
    if (!error && delimRegex) {
        decoded = [delimRegex stringByReplacingMatchesInString:decoded
                                                       options:0
                                                         range:NSMakeRange(0, decoded.length)
                                                  withTemplate:@" "];
    }

    // 6. Clean whitespace and capitalize words
    decoded = [decoded stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [decoded capitalizedString];
}

@end
