package com.player.core

/**
 * Interface for triggering native player hardware operations (ExoPlayer).
 * Matches PlayerCore::IPlaybackEngineBridge in C++.
 */
interface PlayerEngineBridge {
    fun executePlay()
    fun executePause()
    fun executeSeek(seconds: Double)
    fun executePlaybackRate(rate: Float)
    fun executeVolume(volume: Float)
    fun executeMute(muted: Boolean)
}

/**
 * Interface implemented by UI controls, OS services, and telemetry modules.
 * Matches PlayerCore::IPlayerStateObserver in C++.
 */
interface PlayerStateObserver {
    fun onStateChanged(newState: PlaybackState, oldState: PlaybackState)
    fun onTimeUpdated(currentTime: Double, duration: Double)
    fun onBufferUpdated(bufferedTime: Double, percentage: Double)
    fun onMuteChanged(isMuted: Boolean, volume: Float)
    fun onPlaybackRateChanged(rate: Float)
    fun onError(errorCode: Int, message: String)
}
