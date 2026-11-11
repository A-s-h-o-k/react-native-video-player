package com.player

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.ActivityInfo
import android.util.AttributeSet
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.LifecycleEventListener
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.events.RCTEventEmitter
import com.player.audio.AudioFocusManager
import com.player.core.PlaybackState
import com.player.core.PlayerEngineBridge
import com.player.core.PlayerStateCoordinator
import com.player.core.PlayerStateObserver
import com.player.media.MediaSessionManager
import com.player.metadata.MediaMetadataResolver
import com.player.network.DrmConfig
import com.player.network.DrmType
import com.player.subtitles.SubtitleListener
import com.player.subtitles.SubtitleManager
import com.player.subtitles.SubtitleTrack
import com.player.thumbnail.ThumbnailProvider
import com.player.ui.ControlLayer
import com.player.videoplayer.BasePlayer
import org.json.JSONObject

class ReactVideoPlayer : FrameLayout {

    private var videoUrl: String = ""
    private var explicitTitle: String = ""
    private var headerMap: Map<String, String>? = null
    private var drmConfig: DrmConfig? = null
    private var isFullscreen: Boolean = false
    private var propFullscreen: Boolean? = null
    private var autoAdjustSafeArea: Boolean = true
    private var fullscreenDialog: Dialog? = null
    private var fullscreenContainer: FrameLayout? = null
    private var originalOrientation: Int = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
    private lateinit var playerRef: BasePlayer
    private lateinit var controlLayer: ControlLayer
    private lateinit var coordinator: PlayerStateCoordinator
    private val metadataResolver = MediaMetadataResolver()
    private lateinit var subtitleManager: SubtitleManager
    private val thumbnailProvider by lazy { ThumbnailProvider(context) }
    private var isReleased: Boolean = false
    private var savedPosition: Long = 0L
    private var hasEmittedLoad: Boolean = false
    private var wasPlayingBeforeFocusLoss: Boolean = false
    private lateinit var audioFocusManager: AudioFocusManager
    private var mediaSessionManager: MediaSessionManager? = null

    private var isLifecycleRegistered: Boolean = false
    private val lifecycleEventListener = object : LifecycleEventListener {
        override fun onHostResume() {
            // Video remains paused where user left off (matching iOS default)
        }

        override fun onHostPause() {
            // Automatically pause playback when app is minimized or backgrounded (matching iOS)
            if (::coordinator.isInitialized && ::playerRef.isInitialized && playerRef.player.isPlaying) {
                coordinator.requestPause()
            }
        }

        override fun onHostDestroy() {
            cleanUp()
        }
    }

    private fun getThemedReactContext(): ThemedReactContext? {
        var ctx: Context? = context
        while (ctx is ContextWrapper) {
            if (ctx is ThemedReactContext) return ctx
            ctx = ctx.baseContext
        }
        return null
    }

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
        androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(this) { _, windowInsets ->
            requestLayout()
            windowInsets
        }
        this.playerRef = BasePlayer(this.context, false, this.videoUrl)
        // Make the PlayerView fill the entire FrameLayout (ReactVideoPlayer) and center it
        val layoutParams = FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT, android.view.Gravity.CENTER)
        this.addView(playerRef.playerView, layoutParams)

        // 1. Create ControlLayer
        this.controlLayer = ControlLayer(this.context)

        // Audio Focus Manager
        this.audioFocusManager = AudioFocusManager(this.context, object : AudioFocusManager.Listener {
            override fun onAudioFocusGained() {
                if (wasPlayingBeforeFocusLoss) {
                    wasPlayingBeforeFocusLoss = false
                    coordinator.requestPlay()
                }
                if (::playerRef.isInitialized) {
                    playerRef.player.volume = 1.0f
                }
            }

            override fun onAudioFocusLost() {
                wasPlayingBeforeFocusLoss = false
                coordinator.requestPause()
            }

            override fun onAudioFocusTransientLoss() {
                wasPlayingBeforeFocusLoss = if (::playerRef.isInitialized) playerRef.player.isPlaying else false
                coordinator.requestPause()
            }

            override fun onAudioFocusDuck() {
                if (::playerRef.isInitialized) {
                    playerRef.player.volume = 0.2f
                }
            }

            override fun onAudioBecomingNoisy() {
                coordinator.requestPause()
            }
        })

        // 2. Initialize Shared C++ State Coordinator via JNI
        val engineBridge = object : PlayerEngineBridge {
            override fun executePlay() {
                audioFocusManager.requestFocus()
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
                    mediaSessionManager?.updatePlaybackState(newState == PlaybackState.Playing)
                }
            }

            override fun onTimeUpdated(currentTime: Double, duration: Double) {
                post {
                    controlLayer.bottomSection.updateTime(currentTime, duration)
                    val buffered = if (::playerRef.isInitialized) {
                        playerRef.player.bufferedPosition.coerceAtLeast(0L).toDouble() / 1000.0
                    } else 0.0
                    emitOnProgress(currentTime, duration, buffered)
                    val isPlaying = if (::playerRef.isInitialized) playerRef.player.isPlaying else false
                    mediaSessionManager?.updatePlaybackState(isPlaying, (currentTime * 1000.0).toLong())
                }
            }

            override fun onBufferUpdated(bufferedTime: Double, percentage: Double) {
                post {
                    controlLayer.bottomSection.updateBuffer(bufferedTime, percentage)
                }
            }

            override fun onMuteChanged(isMuted: Boolean, volume: Float) {}

            override fun onPlaybackRateChanged(rate: Float) {}

            override fun onError(errorCode: Int, message: String) {
                post {
                    controlLayer.setBuffering(false)
                    emitOnError(errorCode, message)
                }
            }
        }

        this.coordinator = PlayerStateCoordinator(engineBridge, stateObserver)

        // Media Session Manager
        this.mediaSessionManager = MediaSessionManager(
            context = this.context,
            player = playerRef.player,
            onPlayRequested = { coordinator.requestPlay() },
            onPauseRequested = { coordinator.requestPause() },
            onSeekRequested = { posMs -> coordinator.requestSeek(posMs / 1000.0) }
        )

        // 3. Attach ExoPlayer and Coordinator to ControlLayer
        this.controlLayer.attachPlayer(playerRef.player, this.coordinator)
        this.controlLayer.onFullscreenToggleRequested = { requestedFs ->
            setFullscreen(requestedFs, notifyJS = true)
        }
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
            if (isPlaying) {
                audioFocusManager.registerNoisyReceiver()
            } else {
                audioFocusManager.unregisterNoisyReceiver()
            }
            coordinator.notifyEngineState(mappedState)

            val dur = playerRef.player.duration.coerceAtLeast(0L).toDouble() / 1000.0
            val cur = playerRef.player.currentPosition.coerceAtLeast(0L).toDouble() / 1000.0
            coordinator.notifyEngineDuration(dur)
            coordinator.notifyEngineTime(cur)

            if (state == Player.STATE_READY && !hasEmittedLoad) {
                hasEmittedLoad = true
                emitOnLoad(dur)
            }
        }

        // 5. Hook video size changes to remeasure playerView as soon as video aspect ratio is resolved
        playerRef.onVideoSizeChangedListener = { _, _ ->
            post {
                if (width > 0 && height > 0) {
                    applySafeAreaLayout(width, height)
                }
            }
        }

        // 6. Initialize SubtitleManager & hook captions toggle
        this.subtitleManager = SubtitleManager(playerRef.player).apply {
            listener = object : SubtitleListener {
                override fun onSubtitlesChanged(availableTracks: List<SubtitleTrack>, activeTrack: SubtitleTrack?) {
                    post {
                        controlLayer.setCaptionsVisible(availableTracks.isNotEmpty())
                        controlLayer.setCaptionsActive(activeTrack != null)
                    }
                }
            }
        }
        this.controlLayer.onCaptionsToggleRequested = {
            subtitleManager.toggleSubtitles()
        }

        // 7. Hook metadata resolution & tracks change
        playerRef.onMediaMetadataChangedListener = { mediaMetadata ->
            val resolved = metadataResolver.resolve(explicitTitle, mediaMetadata, videoUrl)
            post {
                controlLayer.setTitle(resolved.title)
                val dur = if (::playerRef.isInitialized) playerRef.player.duration.coerceAtLeast(0L) else 0L
                mediaSessionManager?.updateMetadata(resolved.title, dur)
                if (resolved.artworkBytes != null) {
                    thumbnailProvider.loadThumbnail(videoUrl, resolved.artworkBytes, headerMap) { _ -> }
                }
            }
        }
        playerRef.onTracksChangedListener = { tracks ->
            subtitleManager.onTracksChanged(tracks)
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
        this.hasEmittedLoad = false
        this.playerRef.videoUrl = url
        this.playerRef.configureNetwork(headerMap, drmConfig)

        // Automatically resolve initial title (from explicit prop or URL slug fallback)
        val initialMetadata = metadataResolver.resolve(explicitTitle, null, url)
        controlLayer.setTitle(initialMetadata.title)
        val dur = if (::playerRef.isInitialized) playerRef.player.duration.coerceAtLeast(0L) else 0L
        mediaSessionManager?.updateMetadata(initialMetadata.title, dur)

        // Asynchronously fetch or extract preview thumbnail
        thumbnailProvider.loadThumbnail(url, null, headerMap) { _ -> }

        this.playerRef.startPlayer()
        coordinator.notifyEngineState(PlaybackState.Loading)
    }

    fun setTitle(title: String) {
        this.explicitTitle = title
        val resolved = metadataResolver.resolve(title, null, videoUrl)
        controlLayer.setTitle(resolved.title)
        val dur = if (::playerRef.isInitialized) playerRef.player.duration.coerceAtLeast(0L) else 0L
        mediaSessionManager?.updateMetadata(resolved.title, dur)
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
        if (isReleased) return
        isReleased = true
        if (::playerRef.isInitialized) {
            savedPosition = playerRef.player.currentPosition
        }
        if (::audioFocusManager.isInitialized) {
            audioFocusManager.release()
        }
        mediaSessionManager?.release()
        mediaSessionManager = null
        if (isLifecycleRegistered) {
            getThemedReactContext()?.removeLifecycleEventListener(lifecycleEventListener)
            isLifecycleRegistered = false
        }
        if (isFullscreen) {
            setFullscreen(false, notifyJS = false)
        }
        try {
            fullscreenDialog?.dismiss()
        } catch (_: Exception) {}
        fullscreenDialog = null
        fullscreenContainer = null
        thumbnailProvider.release()
        if (::coordinator.isInitialized) {
            coordinator.release()
        }
        if (::playerRef.isInitialized) {
            playerRef.cleanUp()
        }
    }

    fun seekTo(to: Int) {
        coordinator.requestSeek(to.toDouble())
    }

    private fun findActivity(context: Context): Activity? {
        if (context is ThemedReactContext) {
            context.currentActivity?.let { return it }
        }
        var ctx = context
        while (ctx is ContextWrapper) {
            if (ctx is Activity) return ctx
            ctx = ctx.baseContext
        }
        return null
    }

    fun setShowFullscreenButton(show: Boolean) {
        controlLayer.setShowFullscreenButton(show)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        if (!isLifecycleRegistered) {
            getThemedReactContext()?.addLifecycleEventListener(lifecycleEventListener)
            isLifecycleRegistered = true
        }
        androidx.core.view.ViewCompat.requestApplyInsets(this)
        post {
            requestLayout()
        }
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        val width = right - left
        val height = bottom - top
        applySafeAreaLayout(width, height)
    }

    private fun applySafeAreaLayout(width: Int, height: Int) {
        if (isFullscreen) {
            controlLayer.setSafeAreaInsets(0, 0)
            return
        }
        val location = IntArray(2)
        getLocationOnScreen(location)
        val viewScreenY = location[1]

        val statusBarHeight = getStatusBarHeight()
        val navBarHeight = getNavigationBarHeight()

        // 12dp breathing room buffer so controls never touch status bar icons
        val buffer = (12 * resources.displayMetrics.density).toInt()

        // Top inset: only if autoAdjustSafeArea is true and player starts within status bar region
        val topInset = if (autoAdjustSafeArea && viewScreenY < statusBarHeight) {
            (statusBarHeight - viewScreenY) + buffer
        } else {
            0
        }

        // Bottom inset: only if autoAdjustSafeArea is true and player overlaps bottom navigation bar
        val screenHeight = resources.displayMetrics.heightPixels
        val viewBottom = viewScreenY + height
        val bottomThreshold = screenHeight - navBarHeight
        val bottomInset = if (autoAdjustSafeArea && height > 0 && viewBottom > bottomThreshold && navBarHeight > 0) {
            (viewBottom - bottomThreshold).coerceAtLeast(0)
        } else {
            0
        }

        val availHeight = (height - topInset - bottomInset).coerceAtLeast(0)

        // 1. Measure and position video surface inset by safe area
        if (playerRef.playerView.parent == this) {
            val widthSpec = MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY)
            val heightSpec = MeasureSpec.makeMeasureSpec(availHeight, MeasureSpec.EXACTLY)
            playerRef.playerView.measure(widthSpec, heightSpec)
            playerRef.playerView.layout(0, topInset, width, topInset + availHeight)
        }

        // 2. Position control layer full bleed and pass safe insets to top/bottom sections
        if (controlLayer.parent == this) {
            controlLayer.setSafeAreaInsets(topInset, bottomInset)
            controlLayer.measure(
                MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY)
            )
            controlLayer.layout(0, 0, width, height)
        }
    }

    fun setAutoAdjustSafeArea(autoAdjust: Boolean) {
        this.autoAdjustSafeArea = autoAdjust
        post {
            if (width > 0 && height > 0) {
                applySafeAreaLayout(width, height)
            }
            requestLayout()
            invalidate()
        }
    }

    private fun getStatusBarHeight(): Int {
        val activity = findActivity(context)

        // 1. Android 11+ (API 30+): Direct WindowMetrics query (statusBars + displayCutout)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R && activity != null) {
            try {
                val metrics = activity.windowManager.currentWindowMetrics
                val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                    android.view.WindowInsets.Type.statusBars() or android.view.WindowInsets.Type.displayCutout()
                )
                if (insets.top > 0) return insets.top
            } catch (_: Exception) {}
        }

        // 2. ViewCompat root insets fallback on decorView
        val decorView = activity?.window?.decorView
        val rootInsets = decorView?.let { androidx.core.view.ViewCompat.getRootWindowInsets(it) }
            ?: androidx.core.view.ViewCompat.getRootWindowInsets(this)
        val topInset = rootInsets?.getInsets(
            androidx.core.view.WindowInsetsCompat.Type.statusBars() or androidx.core.view.WindowInsetsCompat.Type.displayCutout()
        )?.top ?: 0
        if (topInset > 0) return topInset

        // 3. Fallback to resource dimension or modern floor (at least 36dp)
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        val resHeight = if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 0
        val minModernHeight = (36 * resources.displayMetrics.density).toInt()
        return maxOf(resHeight, minModernHeight)
    }

    private fun getNavigationBarHeight(): Int {
        val activity = findActivity(context)

        // 1. Android 11+ (API 30+): Direct WindowMetrics query for navigationBars
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R && activity != null) {
            try {
                val metrics = activity.windowManager.currentWindowMetrics
                val insets = metrics.windowInsets.getInsetsIgnoringVisibility(
                    android.view.WindowInsets.Type.navigationBars()
                )
                if (insets.bottom > 0) return insets.bottom
            } catch (_: Exception) {}
        }

        // 2. ViewCompat root insets fallback on decorView
        val decorView = activity?.window?.decorView
        val rootInsets = decorView?.let { androidx.core.view.ViewCompat.getRootWindowInsets(it) }
            ?: androidx.core.view.ViewCompat.getRootWindowInsets(this)
        val bottomInset = rootInsets?.getInsets(
            androidx.core.view.WindowInsetsCompat.Type.navigationBars()
        )?.bottom ?: 0
        if (bottomInset > 0) return bottomInset

        val resourceId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        val resHeight = if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 0
        val minModernNav = (24 * resources.displayMetrics.density).toInt()
        return maxOf(resHeight, minModernNav)
    }

    fun setFullscreenProp(value: Boolean) {
        if (propFullscreen == value) return
        propFullscreen = value
        setFullscreen(value, notifyJS = false)
    }

    fun setFullscreen(fullscreen: Boolean, notifyJS: Boolean = false) {
        if (this.isFullscreen == fullscreen) return
        this.isFullscreen = fullscreen

        post {
            controlLayer.setFullscreen(fullscreen)
            val activity = findActivity(context)

            if (fullscreen) {
                if (::playerRef.isInitialized) {
                    savedPosition = playerRef.player.currentPosition
                }
                controlLayer.setSafeAreaInsets(0, 0)
                if (activity != null) {
                    originalOrientation = activity.requestedOrientation

                    val dialog = object : Dialog(activity, android.R.style.Theme_Black_NoTitleBar_Fullscreen) {
                        override fun onBackPressed() {
                            setFullscreen(false, notifyJS = true)
                        }
                    }

                    // 1. Detach playerView and controlLayer from this ReactVideoPlayer view
                    (playerRef.playerView.parent as? ViewGroup)?.removeView(playerRef.playerView)
                    (controlLayer.parent as? ViewGroup)?.removeView(controlLayer)

                    // 2. Create a clean, black MATCH_PARENT container for the dialog
                    val container = FrameLayout(activity).apply {
                        setBackgroundColor(android.graphics.Color.BLACK)
                    }
                    if (autoAdjustSafeArea) {
                        androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(container) { _, insets ->
                            val cutoutInsets = insets.getInsets(
                                androidx.core.view.WindowInsetsCompat.Type.displayCutout()
                            )
                            container.setPadding(cutoutInsets.left, 0, cutoutInsets.right, 0)
                            insets
                        }
                        androidx.core.view.ViewCompat.requestApplyInsets(container)
                    } else {
                        container.setPadding(0, 0, 0, 0)
                    }
                    val playerParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        android.view.Gravity.CENTER
                    )
                    container.addView(playerRef.playerView, playerParams)
                    container.addView(
                        controlLayer,
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.MATCH_PARENT
                        )
                    )

                    dialog.setContentView(
                        container,
                        ViewGroup.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT
                        )
                    )

                    // 3. Configure window for edge-to-edge immersive sticky fullscreen
                    dialog.window?.let { win ->
                        win.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                        win.setBackgroundDrawableResource(android.R.color.black)
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                            win.attributes.layoutInDisplayCutoutMode =
                                android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                        }
                        val controller = WindowInsetsControllerCompat(win, win.decorView)
                        controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                        controller.hide(WindowInsetsCompat.Type.systemBars())
                    }

                    activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                    dialog.show()

                    fullscreenDialog = dialog
                    fullscreenContainer = container

                    if (::playerRef.isInitialized && savedPosition > 0L) {
                        playerRef.player.seekTo(savedPosition)
                    }
                }
            } else {
                if (::playerRef.isInitialized) {
                    savedPosition = playerRef.player.currentPosition
                }
                if (activity != null) {
                    activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                    postDelayed({
                        if (!isFullscreen && !activity.isFinishing && !activity.isDestroyed) {
                            activity.requestedOrientation = originalOrientation
                        }
                    }, 500)
                }

                fullscreenContainer?.let { container ->
                    container.removeView(playerRef.playerView)
                    container.removeView(controlLayer)
                }

                try {
                    fullscreenDialog?.dismiss()
                } catch (_: Exception) {}
                fullscreenDialog = null
                fullscreenContainer = null

                // Re-add playerView and controlLayer back to this ReactVideoPlayer view
                if (playerRef.playerView.parent == null) {
                    val layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        android.view.Gravity.CENTER
                    )
                    addView(playerRef.playerView, layoutParams)
                }
                if (controlLayer.parent == null) {
                    addView(
                        controlLayer,
                        FrameLayout.LayoutParams(
                            FrameLayout.LayoutParams.MATCH_PARENT,
                            FrameLayout.LayoutParams.MATCH_PARENT
                        )
                    )
                }
                if (::playerRef.isInitialized && savedPosition > 0L) {
                    playerRef.player.seekTo(savedPosition)
                }
                post {
                    applySafeAreaLayout(width, height)
                }
            }

            if (notifyJS) {
                emitFullscreenChange(fullscreen)
            }
        }
    }

    private fun emitFullscreenChange(fullscreen: Boolean) {
        try {
            val reactContext = context as? ThemedReactContext ?: return
            val event = Arguments.createMap().apply {
                putBoolean("isFullscreen", fullscreen)
            }
            reactContext.getJSModule(RCTEventEmitter::class.java)
                ?.receiveEvent(id, "onFullscreenChange", event)
        } catch (_: Exception) {}
    }

    fun emitOnError(code: Int, message: String) {
        try {
            val reactContext = context as? ThemedReactContext ?: return
            val event = Arguments.createMap().apply {
                putInt("code", code)
                putString("message", message)
            }
            reactContext.getJSModule(RCTEventEmitter::class.java)
                ?.receiveEvent(id, "onError", event)
        } catch (_: Exception) {}
    }

    fun emitOnProgress(currentTime: Double, duration: Double, playableDuration: Double) {
        try {
            val reactContext = context as? ThemedReactContext ?: return
            val event = Arguments.createMap().apply {
                putDouble("currentTime", currentTime)
                putDouble("duration", duration)
                putDouble("playableDuration", playableDuration)
            }
            reactContext.getJSModule(RCTEventEmitter::class.java)
                ?.receiveEvent(id, "onProgress", event)
        } catch (_: Exception) {}
    }

    fun emitOnLoad(duration: Double) {
        try {
            val reactContext = context as? ThemedReactContext ?: return
            val event = Arguments.createMap().apply {
                putDouble("duration", duration)
            }
            reactContext.getJSModule(RCTEventEmitter::class.java)
                ?.receiveEvent(id, "onLoad", event)
        } catch (_: Exception) {}
    }

    fun setIconsJson(value: String?) {
        controlLayer.setCustomIconsJson(value)
    }

    fun setAccentColor(value: String?) {
        controlLayer.setAccentColor(value)
    }

    fun setTrackColor(value: String?) {
        controlLayer.setTrackColor(value)
    }

    fun setBufferColor(value: String?) {
        controlLayer.setBufferColor(value)
    }

    fun setSkipInterval(value: Int) {
        controlLayer.setSkipInterval(value)
    }

    fun setShowRewindButton(value: Boolean) {
        controlLayer.setShowRewindButton(value)
    }

    fun setShowForwardButton(value: Boolean) {
        controlLayer.setShowForwardButton(value)
    }

    fun setShowPlayPauseButton(value: Boolean) {
        controlLayer.setShowPlayPauseButton(value)
    }

    fun setAutoHideTimeout(value: Int) {
        controlLayer.autoHideTimeoutMs = if (value > 0) value.toLong() else 0L
        controlLayer.resetAutoHideTimer()
    }

    fun setControlsVisible(value: Boolean) {
        controlLayer.setControlsVisible(value)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cleanUp()
    }
}