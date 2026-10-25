package com.player

import android.content.Context
import android.util.AttributeSet
import android.widget.FrameLayout
import androidx.media3.common.Player
import com.player.core.PlaybackState
import com.player.core.PlayerEngineBridge
import com.player.core.PlayerStateCoordinator
import com.player.core.PlayerStateObserver
import com.player.network.DrmConfig
import com.player.network.DrmType
import com.player.ui.ControlLayer
import com.player.videoplayer.BasePlayer
import org.json.JSONObject

class ReactVideoPlayer : FrameLayout {

    private var videoUrl: String = ""
    private var headerMap: Map<String, String>? = null
    private var drmConfig: DrmConfig? = null
    private lateinit var playerRef: BasePlayer
    private lateinit var controlLayer: ControlLayer
    private lateinit var coordinator: PlayerStateCoordinator

    constructor(context: Context) : super(context) {
        configureComponent()
    }

    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs) {
        configureComponent()
    }

    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(context, attrs, defStyleAttr) {
        configureComponent()
    }

    private fun configureComponent() {
        this.setBackgroundColor(android.graphics.Color.BLACK)
        this.playerRef = BasePlayer(this.context, false, this.videoUrl)
        // Make the PlayerView fill the entire FrameLayout (ReactVideoPlayer) and center it
        val layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT, android.view.Gravity.CENTER)
        this.addView(playerRef.playerView, layoutParams)

        // 1. Create ControlLayer
        this.controlLayer = ControlLayer(this.context)

        // 2. Initialize Shared C++ State Coordinator via JNI
        val engineBridge = object : PlayerEngineBridge {
            override fun executePlay() {
                playerRef.play()
            }

            override fun executePause() {
                playerRef.pause()
            }

            override fun executeSeek(seconds: Double) {
                playerRef.player.seekTo((seconds * 1000.0).toLong())
            }

            override fun executePlaybackRate(rate: Float) {
                playerRef.player.setPlaybackSpeed(rate)
            }

            override fun executeVolume(volume: Float) {
                playerRef.player.volume = volume
            }

            override fun executeMute(muted: Boolean) {
                playerRef.player.volume = if (muted) 0f else 1f
            }
        }

        val stateObserver = object : PlayerStateObserver {
            override fun onStateChanged(newState: PlaybackState, oldState: PlaybackState) {
                post {
                    controlLayer.setPlaying(
                        playing = (newState == PlaybackState.Playing),
                        isEnded = (newState == PlaybackState.Ended)
                    )
                    controlLayer.setBuffering(newState == PlaybackState.Buffering)
                }
            }

            override fun onTimeUpdated(currentTime: Double, duration: Double) {
                post {
                    controlLayer.bottomSection.updateTime(currentTime, duration)
                }
            }

            override fun onBufferUpdated(bufferedTime: Double, percentage: Double) {
                // Buffer progress
            }

            override fun onMuteChanged(isMuted: Boolean, volume: Float) {}

            override fun onPlaybackRateChanged(rate: Float) {}

            override fun onError(errorCode: Int, message: String) {
                post {
                    controlLayer.setBuffering(false)
                }
            }
        }

        this.coordinator = PlayerStateCoordinator(engineBridge, stateObserver)

        // 3. Attach ExoPlayer and Coordinator to ControlLayer
        this.controlLayer.attachPlayer(playerRef.player, this.coordinator)
        this.addView(this.controlLayer, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))

        // 4. Hook ExoPlayer events to feed inbound notifications into C++ coordinator
        playerRef.onPlaybackStateListener = { state, isPlaying ->
            val mappedState = when (state) {
                Player.STATE_IDLE -> PlaybackState.Idle
                Player.STATE_BUFFERING -> PlaybackState.Buffering
                Player.STATE_READY -> if (isPlaying) PlaybackState.Playing else PlaybackState.Paused
                Player.STATE_ENDED -> PlaybackState.Ended
                else -> PlaybackState.Idle
            }
            coordinator.notifyEngineState(mappedState)

            val dur = playerRef.player.duration.coerceAtLeast(0L).toDouble() / 1000.0
            val cur = playerRef.player.currentPosition.coerceAtLeast(0L).toDouble() / 1000.0
            coordinator.notifyEngineDuration(dur)
            coordinator.notifyEngineTime(cur)
        }
    }

    fun emitOnScriptLoaded() {

    }

    fun setHeaders(headersJson: String?) {
        if (headersJson.isNullOrEmpty()) {
            this.headerMap = null
        } else {
            try {
                val json = JSONObject(headersJson)
                val map = mutableMapOf<String, String>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    map[key] = json.optString(key, "")
                }
                this.headerMap = map
            } catch (e: Exception) {
                this.headerMap = null
            }
        }
        playerRef.configureNetwork(headerMap, drmConfig)
    }

    fun setDrm(drmJson: String?) {
        if (drmJson.isNullOrEmpty()) {
            this.drmConfig = null
        } else {
            try {
                val json = JSONObject(drmJson)
                val typeStr = json.optString("type", "widevine")
                val drmType = when (typeStr.lowercase()) {
                    "fairplay" -> DrmType.FAIRPLAY
                    "clearkey" -> DrmType.CLEARKEY
                    else -> DrmType.WIDEVINE
                }
                val licenseUrl = json.optString("licenseUrl", "")
                val certUrl = if (json.has("certificateUrl")) json.optString("certificateUrl") else null
                var drmHeaders: Map<String, String>? = null
                if (json.has("headers")) {
                    val hJson = json.optJSONObject("headers")
                    if (hJson != null) {
                        val hMap = mutableMapOf<String, String>()
                        val keys = hJson.keys()
                        while (keys.hasNext()) {
                            val k = keys.next()
                            hMap[k] = hJson.optString(k, "")
                        }
                        drmHeaders = hMap
                    }
                }
                val multiSession = json.optBoolean("multiSession", false)
                this.drmConfig = DrmConfig(
                    type = drmType,
                    licenseServerUrl = licenseUrl,
                    headers = drmHeaders ?: emptyMap(),
                    certificateUrl = certUrl,
                    multiSession = multiSession
                )
            } catch (e: Exception) {
                this.drmConfig = null
            }
        }
        playerRef.configureNetwork(headerMap, drmConfig)
    }

    fun setUrl(url: String) {
        this.videoUrl = url
        this.playerRef.videoUrl = url
        this.playerRef.configureNetwork(headerMap, drmConfig)
        this.playerRef.startPlayer()
        coordinator.notifyEngineState(PlaybackState.Loading)
    }

    fun setTitle(title: String) {
        controlLayer.setTitle(title)
    }

    fun setResizeMode(mode: String?) {
        playerRef.setResizeMode(mode)
    }

    fun playVideo() {
        coordinator.requestPlay()
    }

    fun pauseVideo() {
        coordinator.requestPause()
    }

    fun cleanUp() {
        coordinator.release()
        playerRef.cleanUp()
    }

    fun seekTo(to: Int) {
        coordinator.requestSeek(to.toDouble())
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cleanUp()
    }
}