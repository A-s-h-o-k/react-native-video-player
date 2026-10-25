//
//  NetworkAuthManager.h
//  Player
//
//  Dedicated networking, custom authorization headers, native request interceptor,
//  and FairPlay DRM key session manager for iOS / tvOS.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NetworkAuthManagerDelegate <NSObject>
@optional
- (void)networkAuthManagerDidEncounterDrmError:(NSError *)error;
- (void)networkAuthManagerDidRefreshAuthToken:(NSString *)newToken;
@end

@interface NetworkAuthManager : NSObject <AVContentKeySessionDelegate, AVAssetResourceLoaderDelegate>

@property (nonatomic, weak, nullable) id<NetworkAuthManagerDelegate> delegate;

@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, copy, nullable) NSString *drmLicenseServerUrl;
@property (nonatomic, copy, nullable) NSString *drmCertificateUrl;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *drmHeaders;

- (instancetype)init;

/// Configures custom headers and FairPlay DRM settings
- (void)configureWithHeaders:(nullable NSDictionary<NSString *, NSString *> *)headers
                   drmConfig:(nullable NSDictionary<NSString *, id> *)drmConfig;

/// Creates an AVPlayerItem with attached headers, resource loader interceptor, and DRM key session
- (AVPlayerItem *)createPlayerItemForURL:(NSURL *)url;

/// Updates the active Authorization bearer token mid-stream
- (void)updateAuthToken:(NSString *)newToken;

/// Releases key sessions and resource loaders
- (void)cleanup;

@end

NS_ASSUME_NONNULL_END
