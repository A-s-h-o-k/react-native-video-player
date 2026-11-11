package com.player.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.util.Log

class AudioFocusManager(
    private val context: Context,
    private val listener: Listener
) {
    interface Listener {
        fun onAudioFocusGained()
        fun onAudioFocusLost()
        fun onAudioFocusTransientLoss()
        fun onAudioFocusDuck()
        fun onAudioBecomingNoisy()
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false

    // Headphone unplug receiver (FIX for H-A13)
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (AudioManager.ACTION_AUDIO_BECOMING_NOISY == intent?.action) {
                listener.onAudioBecomingNoisy()
            }
        }
    }
    private var noisyReceiverRegistered = false

    private val focusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                hasAudioFocus = true
                listener.onAudioFocusGained()
            }
            AudioManager.AUDIOFOCUS_LOSS -> {
                hasAudioFocus = false
                listener.onAudioFocusLost()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                hasAudioFocus = false
                listener.onAudioFocusTransientLoss()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                listener.onAudioFocusDuck()
            }
        }
    }

    fun requestFocus(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attrs)
                .setOnAudioFocusChangeListener(focusChangeListener)
                .setWillPauseWhenDucked(false)
                .build()
            focusRequest = request
            val result = audioManager.requestAudioFocus(request)
            hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            @Suppress("DEPRECATION")
            val result = audioManager.requestAudioFocus(
                focusChangeListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
            hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
        return hasAudioFocus
    }

    fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(focusChangeListener)
        }
        hasAudioFocus = false
    }

    fun registerNoisyReceiver() {
        if (!noisyReceiverRegistered) {
            val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            context.registerReceiver(noisyReceiver, filter)
            noisyReceiverRegistered = true
        }
    }

    fun unregisterNoisyReceiver() {
        if (noisyReceiverRegistered) {
            try {
                context.unregisterReceiver(noisyReceiver)
            } catch (e: IllegalArgumentException) {
                Log.w("AudioFocusManager", "Receiver already unregistered", e)
            }
            noisyReceiverRegistered = false
        }
    }

    fun release() {
        abandonFocus()
        unregisterNoisyReceiver()
    }
}
