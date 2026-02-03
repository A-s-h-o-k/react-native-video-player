package com.player

import android.content.Context
import android.util.AttributeSet
import android.widget.FrameLayout
import android.view.Gravity
import com.player.videoplayer.BasePlayer


class ReactVideoPlayer : FrameLayout    {


   private var videoUrl : String = "";
   private lateinit var playerRef : BasePlayer;


    constructor(context: Context) : super(context) {
        configureComponent()
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        configureComponent()
    }

    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(context, attrs, defStyleAttr) {
        configureComponent()
    }



    private fun configureComponent()  {

        this.playerRef = BasePlayer(this.context, false, this.videoUrl)
        // Make the PlayerView fill the entire FrameLayout (ReactVideoPlayer)
        val layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        this.addView(playerRef.playerView, layoutParams)
    }

    fun emitOnScriptLoaded() {

    }

    fun setUrl(url:String) {
        this.videoUrl = url;
        this.playerRef.videoUrl = url;
        this.playerRef.startPlayer();
    }

    fun playVideo() {
        playerRef.play()
    }

    fun pauseVideo() {
        playerRef.pause()
    }

    fun cleanUp() {
        playerRef.cleanUp()
    }

    fun seekTo(to: Int) {
        playerRef.player.seekTo(to.toLong())
    }

}