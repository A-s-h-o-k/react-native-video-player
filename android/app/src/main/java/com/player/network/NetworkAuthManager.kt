package com.player.network

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.DrmSessionManager
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource

/**
 * Dedicated networking and authorization manager for Android / Android TV.
 *
 * Configures HTTP headers, bearer tokens, Widevine hardware DRM, and media sources.
 */
@OptIn(UnstableApi::class)
class NetworkAuthManager {

    var headers: Map<String, String> = emptyMap()
    var drmConfig: DrmConfig? = null

    fun configure(headers: Map<String, String>?, drmConfig: DrmConfig?) {
        this.headers = headers ?: emptyMap()
        this.drmConfig = drmConfig
    }

    fun updateAuthToken(newToken: String) {
        val updated = headers.toMutableMap()
        updated["Authorization"] = "Bearer $newToken"
        this.headers = updated
    }

    /**
     * Builds HTTP and local DataSource factory with injected authorization headers.
     */
    fun buildDataSourceFactory(context: Context): DataSource.Factory {
        val httpFactory = DefaultHttpDataSource.Factory()
            .setUserAgent("EnterpriseVideoPlayer/1.0 (Android)")
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15000)
            .setReadTimeoutMs(15000)

        if (headers.isNotEmpty()) {
            httpFactory.setDefaultRequestProperties(headers)
        }

        return DefaultDataSource.Factory(context, httpFactory)
    }

    /**
     * Configures Widevine modular DRM session manager with custom license authorization headers.
     */
    fun buildDrmSessionManager(): DrmSessionManager? {
        val config = drmConfig ?: return null
        if (config.type != DrmType.WIDEVINE || config.licenseServerUrl.isBlank()) {
            return null
        }

        val httpDrmFactory = DefaultHttpDataSource.Factory()
        if (config.headers.isNotEmpty()) {
            httpDrmFactory.setDefaultRequestProperties(config.headers)
        }

        val drmCallback = HttpMediaDrmCallback(config.licenseServerUrl, httpDrmFactory)

        return DefaultDrmSessionManager.Builder()
            .setUuidAndExoMediaDrmProvider(C.WIDEVINE_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
            .setMultiSession(config.multiSession)
            .build(drmCallback)
    }

    /**
     * Builds configured MediaItem with DRM parameters attached.
     */
    fun buildMediaItem(videoUrl: String): MediaItem {
        val builder = MediaItem.Builder().setUri(videoUrl)
        val config = drmConfig

        if (config != null && config.type == DrmType.WIDEVINE && config.licenseServerUrl.isNotBlank()) {
            val drmBuilder = MediaItem.DrmConfiguration.Builder(C.WIDEVINE_UUID)
                .setLicenseUri(config.licenseServerUrl)
                .setMultiSession(config.multiSession)

            if (config.headers.isNotEmpty()) {
                drmBuilder.setLicenseRequestHeaders(config.headers)
            }
            builder.setDrmConfiguration(drmBuilder.build())
        }

        return builder.build()
    }

    /**
     * Builds complete MediaSource with custom data source factory and DRM session manager.
     */
    fun buildMediaSource(context: Context, videoUrl: String): MediaSource {
        val dataSourceFactory = buildDataSourceFactory(context)
        val drmManager = buildDrmSessionManager()
        val mediaItem = buildMediaItem(videoUrl)

        val factory = DefaultMediaSourceFactory(dataSourceFactory)
        if (drmManager != null) {
            factory.setDrmSessionManagerProvider { drmManager }
        }

        return factory.createMediaSource(mediaItem)
    }
}
