package com.player.videoplayer


import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.media3.common.MediaItem
import android.content.Context
import android.view.Gravity
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Metadata
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.LoadEventInfo
import androidx.media3.exoplayer.source.MediaLoadData
import androidx.media3.ui.AspectRatioFrameLayout
import com.player.network.DrmConfig
import com.player.network.NetworkAuthManager

@OptIn(UnstableApi::class)
open class BasePlayer(private val context: Context, var play : Boolean = false, var videoUrl : String) {

    val networkAuthManager = NetworkAuthManager()
    val loadControl = DefaultLoadControl.Builder()
        .setBufferDurationsMs(
            15000, // minBufferMs: minimum target buffer maintained (15s)
            30000, // maxBufferMs: maximum buffer ceiling (30s)
            1000,  // bufferForPlaybackMs: preroll to start/seek (1.0s, reduced from 2.5s for fast TTFF)
            3000   // bufferForPlaybackAfterRebufferMs: rebuffer after stall (3.0s, reduced from 5s)
        )
        .setPrioritizeTimeOverSizeThresholds(true)
        .build()

    val player: ExoPlayer = ExoPlayer.Builder(context)
        .setLoadControl(loadControl)
        .build()
    val playerView: PlayerView = PlayerView(context)
    val playing: Boolean = play

    var onPlaybackStateListener: ((state: Int, isPlaying: Boolean) -> Unit)? = null
    var onMetadataListener: ((metadata: Metadata) -> Unit)? = null
    var onMediaMetadataChangedListener: ((mediaMetadata: MediaMetadata) -> Unit)? = null
    var onTracksChangedListener: ((tracks: androidx.media3.common.Tracks) -> Unit)? = null
    var onNetworkMetricsListener: ((pingMs: Long, throughputBps: Long) -> Unit)? = null
    var onVideoSizeChangedListener: ((width: Int, height: Int) -> Unit)? = null

    init {
        this.playerView.setBackgroundColor(android.graphics.Color.BLACK)
        this.playerView.useController = false
        this.playerView.controllerAutoShow = false
    }

    fun configureNetwork(headers: Map<String, String>?, drmConfig: DrmConfig?) {
        networkAuthManager.configure(headers, drmConfig)
    }

    @OptIn(UnstableApi::class)
    fun setResizeMode(mode: String?) {
        when (mode?.lowercase()) {
            "cover" -> this.playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
            "stretch" -> this.playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FILL
            else -> this.playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        }
    }

    @OptIn(UnstableApi::class)
    fun startPlayer() {
        val mediaSource = networkAuthManager.buildMediaSource(context, videoUrl)
        this.player.setMediaSource(mediaSource)
        this.player.prepare();
        this.player.playWhenReady = this.play;
        this.playerView.player = this.player
        this.playerView.useController = false
        this.player.addListener(object : Player.Listener {
            override fun onVideoSizeChanged(videoSize: VideoSize) {
                if (videoSize.width > 0 && videoSize.height > 0) {
                    onVideoSizeChangedListener?.invoke(videoSize.width, videoSize.height)
                }
            }
            override fun onIsPlayingChanged(isPlaying: Boolean) {
                onPlaybackStateListener?.invoke(player.playbackState, isPlaying)
            }
            override fun onPlaybackStateChanged(state: Int) {
                onPlaybackStateListener?.invoke(state, player.isPlaying)
                when (state) {
                    Player.STATE_BUFFERING -> {
                        // The video is LOADING
                    }
                    Player.STATE_READY -> {
                        // Player is ready
                    }
                    Player.STATE_IDLE -> {
                        // Player is created but has no media
                    }
                    Player.STATE_ENDED -> {
                        // Video finished playing
                    }
                }
            }
            override fun onMetadata(metadata: Metadata) {
                onMetadataListener?.invoke(metadata)
            }
            override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
                onMediaMetadataChangedListener?.invoke(mediaMetadata)
            }
            override fun onTracksChanged(tracks: androidx.media3.common.Tracks) {
                onTracksChangedListener?.invoke(tracks)
            }
        })
        this.player.addAnalyticsListener(object : AnalyticsListener {
            override fun onLoadCompleted(
                eventTime: AnalyticsListener.EventTime,
                loadEventInfo: LoadEventInfo,
                mediaLoadData: MediaLoadData
            ) {
                val pingMs = loadEventInfo.loadDurationMs
                val bytes = loadEventInfo.bytesLoaded
                val throughputBps = if (pingMs > 0) (bytes * 8000L) / pingMs else 0L
                onNetworkMetricsListener?.invoke(pingMs, throughputBps)
            }
        })
    }

    fun play() {
        this.play = true;
        this.player.play()
    }


    fun pause() {
        this.play = false
        this.player.pause()
    }


    fun cleanUp() {
        this.player.stop()
        this.player.release()
    }



}