package com.player.network

/**
 * Supported DRM schemes.
 */
enum class DrmType {
    WIDEVINE,
    FAIRPLAY,
    CLEARKEY
}

/**
 * Configuration options for hardware DRM (Widevine on Android, FairPlay on iOS).
 */
data class DrmConfig(
    val type: DrmType = DrmType.WIDEVINE,
    val licenseServerUrl: String,
    val certificateUrl: String? = null,
    val headers: Map<String, String> = emptyMap(),
    val multiSession: Boolean = true
)
