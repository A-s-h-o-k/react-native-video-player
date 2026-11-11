package com.player.media

import android.content.Context
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.view.KeyEvent
import androidx.media3.exoplayer.ExoPlayer
import com.player.core.PlayerSnapshot

/**
 * Native Android MediaSession manager integrating OS transport controls,
 * hardware media buttons, Bluetooth headsets, and Now Playing metadata.
 */
class MediaSessionManager(
    private val context: Context,
    private val player: ExoPlayer,
    private val onPlayRequested: () -> Unit = { player.play() },
    private val onPauseRequested: () -> Unit = { player.pause() },
    private val onSeekRequested: (Long) -> Unit = { positionMs -> player.seekTo(positionMs) }
) {
    private var mediaSession: MediaSession? = null

    init {
        createMediaSession()
    }

    private fun createMediaSession() {
        try {
            val session = MediaSession(context, "ReactVideoPlayerSession").apply {
                setCallback(object : MediaSession.Callback() {
                    override fun onPlay() {
                        onPlayRequested()
                    }

                    override fun onPause() {
                        onPauseRequested()
                    }

                    override fun onSeekTo(pos: Long) {
                        onSeekRequested(pos)
                    }

                    override fun onStop() {
                        onPauseRequested()
                    }

                    override fun onMediaButtonEvent(mediaButtonIntent: Intent): Boolean {
                        val keyEvent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            mediaButtonIntent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
                        } ?: return super.onMediaButtonEvent(mediaButtonIntent)

                        if (keyEvent.action == KeyEvent.ACTION_DOWN) {
                            when (keyEvent.keyCode) {
                                KeyEvent.KEYCODE_MEDIA_PLAY -> {
                                    onPlayRequested()
                                    return true
                                }
                                KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                                    onPauseRequested()
                                    return true
                                }
                                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                                KeyEvent.KEYCODE_HEADSETHOOK -> {
                                    if (player.isPlaying) {
                                        onPauseRequested()
                                    } else {
                                        onPlayRequested()
                                    }
                                    return true
                                }
                                KeyEvent.KEYCODE_MEDIA_STOP -> {
                                    onPauseRequested()
                                    return true
                                }
                            }
                        }
                        return super.onMediaButtonEvent(mediaButtonIntent)
                    }
                })

                setFlags(
                    MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or
                    MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS
                )
                isActive = true
            }
            mediaSession = session
        } catch (_: Exception) {}
    }

    fun updatePlaybackState(isPlaying: Boolean, currentPositionMs: Long = player.currentPosition, speed: Float = 1.0f) {
        val session = mediaSession ?: return
        val state = if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED
        val actions = PlaybackState.ACTION_PLAY or
                PlaybackState.ACTION_PAUSE or
                PlaybackState.ACTION_PLAY_PAUSE or
                PlaybackState.ACTION_SEEK_TO or
                PlaybackState.ACTION_STOP

        val pbState = PlaybackState.Builder()
            .setActions(actions)
            .setState(state, currentPositionMs, speed)
            .build()
        session.setPlaybackState(pbState)
    }

    fun updateMetadata(title: String, durationMs: Long) {
        val session = mediaSession ?: return
        val metadata = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)
            .build()
        session.setMetadata(metadata)
    }

    fun updateFromSnapshot(snapshot: PlayerSnapshot) {
        val isPlaying = snapshot.state == com.player.core.PlaybackState.Playing
        updatePlaybackState(isPlaying, (snapshot.currentTime * 1000.0).toLong(), snapshot.playbackRate)
    }

    fun release() {
        try {
            mediaSession?.isActive = false
            mediaSession?.release()
        } catch (_: Exception) {}
        mediaSession = null
    }
}
