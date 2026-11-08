//
//  NetworkAuthManager.mm
//  Player
//
//  Dedicated networking, custom authorization headers, native request interceptor,
//  and FairPlay DRM key session manager for iOS / tvOS.
//

#import "NetworkAuthManager.h"

@interface NetworkAuthManager ()

@property (nonatomic, strong, nullable) AVContentKeySession *contentKeySession;
@property (nonatomic, strong, nullable) NSData *appCertificateData;
@property (nonatomic, strong) dispatch_queue_t resourceLoaderQueue;
@property (nonatomic, strong) dispatch_queue_t drmQueue;

@end

@implementation NetworkAuthManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _resourceLoaderQueue = dispatch_queue_create("com.player.network.resourceloader", DISPATCH_QUEUE_SERIAL);
        _drmQueue = dispatch_queue_create("com.player.network.drm", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)configureWithHeaders:(nullable NSDictionary<NSString *, NSString *> *)headers
                   drmConfig:(nullable NSDictionary<NSString *, id> *)drmConfig {
    _headers = [headers copy];

    if (drmConfig) {
        _drmLicenseServerUrl = [drmConfig[@"licenseServerUrl"] copy];
        _drmCertificateUrl = [drmConfig[@"certificateUrl"] copy];
        _drmHeaders = [drmConfig[@"headers"] copy];

        // Pre-fetch Apple Application Certificate if URL is provided
        if (_drmCertificateUrl.length > 0) {
            [self fetchApplicationCertificateWithUrl:[NSURL URLWithString:_drmCertificateUrl]];
        }
    }
}

- (AVPlayerItem *)createPlayerItemForURL:(NSURL *)url {
    NSMutableDictionary *assetOptions = [NSMutableDictionary dictionary];

    // 1. Attach Custom HTTP Authorization Headers
    if (self.headers.count > 0) {
        assetOptions[@"AVURLAssetHTTPHeaderFieldsKey"] = self.headers;
    }

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:assetOptions];

    // 2. Setup FairPlay DRM if license URL is provided
    if (self.drmLicenseServerUrl.length > 0) {
        if (@available(iOS 11.0, tvOS 11.0, *)) {
            self.contentKeySession = [AVContentKeySession contentKeySessionWithKeySystem:AVContentKeySystemFairPlayStreaming];
            [self.contentKeySession setDelegate:self queue:self.drmQueue];
        }
    }

    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];

    // 3. Attach FairPlay Key Recipient to Asset
    if (self.contentKeySession && asset) {
        if (@available(iOS 11.0, tvOS 11.0, *)) {
            [self.contentKeySession addContentKeyRecipient:asset];
        }
    }

    return playerItem;
}

- (void)updateAuthToken:(NSString *)newToken {
    if (!newToken) return;
    NSMutableDictionary *updatedHeaders = [self.headers mutableCopy] ?: [NSMutableDictionary dictionary];
    updatedHeaders[@"Authorization"] = [NSString stringWithFormat:@"Bearer %@", newToken];
    self.headers = updatedHeaders;
    
    if ([self.delegate respondsToSelector:@selector(networkAuthManagerDidRefreshAuthToken:)]) {
        [self.delegate networkAuthManagerDidRefreshAuthToken:newToken];
    }
}

#pragma mark - FairPlay DRM Key Exchange

- (void)fetchApplicationCertificateWithUrl:(NSURL *)certUrl {
    dispatch_async(self.drmQueue, ^{
        NSError *error = nil;
        NSData *certData = [NSData dataWithContentsOfURL:certUrl options:0 error:&error];
        if (certData) {
            self.appCertificateData = certData;
        } else if (error) {
            NSLog(@"[NetworkAuthManager] Failed to fetch FairPlay Certificate: %@", error.localizedDescription);
            if ([self.delegate respondsToSelector:@selector(networkAuthManagerDidEncounterDrmError:)]) {
                [self.delegate networkAuthManagerDidEncounterDrmError:error];
            }
        }
    });
}

#pragma mark - AVContentKeySessionDelegate

- (void)contentKeySession:(AVContentKeySession *)session didProvideContentKeyRequest:(AVContentKeyRequest *)keyRequest API_AVAILABLE(ios(11.0), tvos(11.0)) {
    // 1. Ensure Application Certificate exists
    if (!self.appCertificateData) {
        if (self.drmCertificateUrl.length > 0) {
            self.appCertificateData = [NSData dataWithContentsOfURL:[NSURL URLWithString:self.drmCertificateUrl]];
        }
        if (!self.appCertificateData) {
            NSError *certErr = [NSError errorWithDomain:@"com.player.drm" code:400 userInfo:@{NSLocalizedDescriptionKey: @"FairPlay Application Certificate missing"}];
            [keyRequest processContentKeyResponseError:certErr];
            return;
        }
    }

    // 2. Extract Content Identifier (Asset ID)
    NSURL *identifierURL = (NSURL *)keyRequest.identifier;
    NSString *assetId = identifierURL.host;
    if (!assetId) {
        assetId = identifierURL.absoluteString;
    }
    NSData *assetIdData = [assetId dataUsingEncoding:NSUTF8StringEncoding];

    // 3. Generate SPC (Server Playback Context) via Apple Secure Enclave
    [keyRequest makeStreamingContentKeyRequestDataForApp:self.appCertificateData
                                      contentIdentifier:assetIdData
                                                options:nil
                                      completionHandler:^(NSData * _Nullable spcData, NSError * _Nullable error) {
        if (error || !spcData) {
            NSLog(@"[NetworkAuthManager] Failed to create SPC: %@", error.localizedDescription);
            [keyRequest processContentKeyResponseError:error];
            return;
        }

        // 4. Send SPC to FairPlay KSM (License Server)
        NSURL *licenseUrl = [NSURL URLWithString:self.drmLicenseServerUrl];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:licenseUrl];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
        req.HTTPBody = spcData;

        // Attach custom DRM headers
        [self.drmHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, __unused BOOL *stop) {
            [req setValue:obj forHTTPHeaderField:key];
        }];

        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable ckcData, NSURLResponse * _Nullable response, NSError * _Nullable netError) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (netError || httpResponse.statusCode >= 400 || !ckcData) {
                NSError *licErr = netError ?: [NSError errorWithDomain:@"com.player.drm" code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey: @"FairPlay license request rejected"}];
                [keyRequest processContentKeyResponseError:licErr];
                if ([self.delegate respondsToSelector:@selector(networkAuthManagerDidEncounterDrmError:)]) {
                    [self.delegate networkAuthManagerDidEncounterDrmError:licErr];
                }
                return;
            }

            // 5. Load CKC into secure pipeline for hardware GPU decryption
            AVContentKeyResponse *keyResponse = [AVContentKeyResponse contentKeyResponseWithFairPlayStreamingKeyResponseData:ckcData];
            [keyRequest processContentKeyResponse:keyResponse];
        }];
        [task resume];
    }];
}

#pragma mark - Cleanup

- (void)cleanup {
    if (self.contentKeySession) {
        if (@available(iOS 11.0, tvOS 11.0, *)) {
            [self.contentKeySession setDelegate:nil queue:nil];
        }
        self.contentKeySession = nil;
    }
    self.appCertificateData = nil;
}

- (void)dealloc {
    [self cleanup];
}

@end
