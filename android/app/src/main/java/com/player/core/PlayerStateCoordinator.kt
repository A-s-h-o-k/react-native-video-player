package com.player.core

import android.os.Handler
import android.os.Looper

/**
 * Kotlin facade for the shared pure C++ PlayerStateCoordinator.
 *
 * Runs the deterministic state machine, 3-phase scrub engine, and delivers
 * state and time updates directly to the Android UI.
 */
class PlayerStateCoordinator(
    private val engineBridge: PlayerEngineBridge,
    private val observer: PlayerStateObserver
) {
    private var nativeHandle: Long = 0L
    private val mainHandler = Handler(Looper.getMainLooper())

    // Internal JNI bridge callback object
    private val internalEngineBridge = object {
        fun executePlay() {
            mainHandler.post { engineBridge.executePlay() }
        }

        fun executePause() {
            mainHandler.post { engineBridge.executePause() }
        }

        fun executeSeek(seconds: Double) {
            mainHandler.post { engineBridge.executeSeek(seconds) }
        }

        fun executePlaybackRate(rate: Float) {
            mainHandler.post { engineBridge.executePlaybackRate(rate) }
        }

        fun executeVolume(volume: Float) {
            mainHandler.post { engineBridge.executeVolume(volume) }
        }

        fun executeMute(muted: Boolean) {
            mainHandler.post { engineBridge.executeMute(muted) }
        }
    }

    // Internal JNI observer callback object
    private val internalObserver = object {
        fun onStateChanged(newOrdinal: Int, oldOrdinal: Int) {
            val newState = PlaybackState.fromInt(newOrdinal)
            val oldState = PlaybackState.fromInt(oldOrdinal)
            mainHandler.post { observer.onStateChanged(newState, oldState) }
        }

        fun onTimeUpdated(currentTime: Double, duration: Double) {
            mainHandler.post { observer.onTimeUpdated(currentTime, duration) }
        }

        fun onBufferUpdated(bufferedTime: Double, percentage: Double) {
            mainHandler.post { observer.onBufferUpdated(bufferedTime, percentage) }
        }

        fun onMuteChanged(isMuted: Boolean, volume: Float) {
            mainHandler.post { observer.onMuteChanged(isMuted, volume) }
        }

        fun onPlaybackRateChanged(rate: Float) {
            mainHandler.post { observer.onPlaybackRateChanged(rate) }
        }

        fun onError(errorCode: Int, message: String) {
            mainHandler.post { observer.onError(errorCode, message) }
        }
    }

    init {
        nativeHandle = nativeCreate(internalEngineBridge, internalObserver)
    }

    // --- Inbound Requests from UI & RN ---

    fun requestPlay() {
        if (nativeHandle != 0L) nativeRequestPlay(nativeHandle)
    }

    fun requestPause() {
        if (nativeHandle != 0L) nativeRequestPause(nativeHandle)
    }

    fun requestTogglePlayPause() {
        if (nativeHandle != 0L) nativeRequestTogglePlayPause(nativeHandle)
    }

    fun requestSeek(seconds: Double) {
        if (nativeHandle != 0L) nativeRequestSeek(nativeHandle, seconds)
    }

    fun requestStepSeek(deltaSeconds: Double) {
        if (nativeHandle != 0L) nativeRequestStepSeek(nativeHandle, deltaSeconds)
    }

    // 3-Phase Scrubbing Lifecycle
    fun startScrubbing() {
        if (nativeHandle != 0L) nativeStartScrubbing(nativeHandle)
    }

    fun scrubTo(seconds: Double) {
        if (nativeHandle != 0L) nativeScrubTo(nativeHandle, seconds)
    }

    fun endScrubbing(seconds: Double) {
        if (nativeHandle != 0L) nativeEndScrubbing(nativeHandle, seconds)
    }

    // --- Inbound Engine Notifications from ExoPlayer ---

    fun notifyEngineState(state: PlaybackState) {
        if (nativeHandle != 0L) nativeNotifyEngineState(nativeHandle, state.ordinal)
    }

    fun notifyEngineTime(currentTime: Double) {
        if (nativeHandle != 0L) nativeNotifyEngineTime(nativeHandle, currentTime)
    }

    fun notifyEngineDuration(duration: Double) {
        if (nativeHandle != 0L) nativeNotifyEngineDuration(nativeHandle, duration)
    }

    fun notifyEngineBuffer(bufferedTime: Double) {
        if (nativeHandle != 0L) nativeNotifyEngineBuffer(nativeHandle, bufferedTime)
    }

    fun notifyEngineError(errorCode: Int, message: String) {
        if (nativeHandle != 0L) nativeNotifyEngineError(nativeHandle, errorCode, message)
    }

    // --- State Queries ---

    fun getPlaybackState(): PlaybackState {
        return if (nativeHandle != 0L) PlaybackState.fromInt(nativeGetPlaybackState(nativeHandle)) else PlaybackState.Idle
    }

    fun getCurrentTime(): Double {
        return if (nativeHandle != 0L) nativeGetCurrentTime(nativeHandle) else 0.0
    }

    fun getDuration(): Double {
        return if (nativeHandle != 0L) nativeGetDuration(nativeHandle) else 0.0
    }

    fun isScrubbing(): Boolean {
        return if (nativeHandle != 0L) nativeIsScrubbing(nativeHandle) else false
    }

    fun release() {
        if (nativeHandle != 0L) {
            nativeDestroy(nativeHandle)
            nativeHandle = 0L
        }
    }

    companion object {
        init {
            try {
                System.loadLibrary("appmodules")
            } catch (e: UnsatisfiedLinkError) {
                // Ignore if appmodules is loaded by React Native Fabric at application init
            }
        }
    }

    // Native JNI functions
    private external fun nativeCreate(engineBridge: Any, observer: Any): Long
    private external fun nativeDestroy(handle: Long)
    private external fun nativeRequestPlay(handle: Long)
    private external fun nativeRequestPause(handle: Long)
    private external fun nativeRequestTogglePlayPause(handle: Long)
    private external fun nativeRequestSeek(handle: Long, seconds: Double)
    private external fun nativeRequestStepSeek(handle: Long, deltaSeconds: Double)
    private external fun nativeStartScrubbing(handle: Long)
    private external fun nativeScrubTo(handle: Long, seconds: Double)
    private external fun nativeEndScrubbing(handle: Long, seconds: Double)
    private external fun nativeNotifyEngineState(handle: Long, state: Int)
    private external fun nativeNotifyEngineTime(handle: Long, currentTime: Double)
    private external fun nativeNotifyEngineDuration(handle: Long, duration: Double)
    private external fun nativeNotifyEngineBuffer(handle: Long, bufferedTime: Double)
    private external fun nativeNotifyEngineError(handle: Long, errorCode: Int, message: String)
    private external fun nativeGetPlaybackState(handle: Long): Int
    private external fun nativeGetCurrentTime(handle: Long): Double
    private external fun nativeGetDuration(handle: Long): Double
    private external fun nativeIsScrubbing(handle: Long): Boolean
}
