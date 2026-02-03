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

open class BasePlayer(private val context: Context, var play : Boolean = false, var videoUrl : String) {

    

    val player : ExoPlayer = ExoPlayer.Builder(context).build();
    val playerView : PlayerView = PlayerView(context);
    val playing : Boolean = play;


    private lateinit var currentMediaItem : MediaItem;

    @OptIn(UnstableApi::class)
    fun startPlayer() {
        this.currentMediaItem = MediaItem.fromUri(videoUrl)
        this.player.setMediaItem(this.currentMediaItem)
        this.player.prepare();
        this.player.playWhenReady = this.play;
        this.playerView.player = this.player
//        val params = FrameLayout.LayoutParams(
//            FrameLayout.LayoutParams.MATCH_PARENT, // Width: Fill the container
//            FrameLayout.LayoutParams.WRAP_CONTENT  // Height: Fill the container
//        )
//        params.gravity = Gravity.CENTER
        this.playerView.resizeMode = AspectRatioFrameLayout.RESIZE_MODE_FIT
        this.player.addListener(object : Player.Listener {
            override fun onVideoSizeChanged(videoSize: VideoSize) {

            }
            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_BUFFERING -> {
                        // The video is LOADING (show your progress bar)
                    }
                    Player.STATE_READY -> {
                        // Player is ready. The view will resize automatically based on the video's aspect ratio.
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
        // this.player.
    }



}