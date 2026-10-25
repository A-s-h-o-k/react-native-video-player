package com.player.videoplayer


import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.media3.common.MediaItem
import android.content.Context
import android.view.Gravity
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.ui.AspectRatioFrameLayout
import com.player.network.DrmConfig
import com.player.network.NetworkAuthManager

open class BasePlayer(private val context: Context, var play : Boolean = false, var videoUrl : String) {

    val networkAuthManager = NetworkAuthManager()
    val player : ExoPlayer = ExoPlayer.Builder(context).build();
    val playerView : PlayerView = PlayerView(context);
    val playing : Boolean = play;

    var onPlaybackStateListener: ((state: Int, isPlaying: Boolean) -> Unit)? = null

    fun configureNetwork(headers: Map<String, String>?, drmConfig: DrmConfig?) {
        networkAuthManager.configure(headers, drmConfig)
    }

    @OptIn(UnstableApi::class)
    fun startPlayer() {
        val mediaSource = networkAuthManager.buildMediaSource(context, videoUrl)
        this.player.setMediaSource(mediaSource)
        this.player.prepare();
        this.player.playWhenReady = this.play;
        this.playerView.player = this.player
        this.playerView.useController = false
        this.playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        this.player.addListener(object : Player.Listener {
            override fun onVideoSizeChanged(videoSize: VideoSize) {

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