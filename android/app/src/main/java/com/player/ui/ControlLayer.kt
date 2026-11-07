package com.player.ui

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ProgressBar
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.player.ui.sections.BottomSection
import com.player.ui.sections.BottomSectionListener
import com.player.ui.sections.CenterSection
import com.player.ui.sections.CenterSectionListener
import com.player.ui.sections.TopSection
import com.player.ui.sections.TopSectionListener

class ControlLayer @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr), CenterSectionListener, BottomSectionListener, TopSectionListener {

    var player: ExoPlayer? = null
    var coordinator: com.player.core.PlayerStateCoordinator? = null
    var isPlaying: Boolean = false
        private set
    var isEnded: Boolean = false
        private set
    var isFullscreen: Boolean = false
        private set
    var onFullscreenToggleRequested: ((Boolean) -> Unit)? = null
    var autoHideTimeoutMs: Long = 5000L

    val topSection: TopSection
    val centerSection: CenterSection
    val bottomSection: BottomSection
    val bufferingSpinner: ProgressBar

    private var controlsVisible: Boolean = true
    private var lastReportedBuffer: Double = -1.0
    private val mainHandler = Handler(Looper.getMainLooper())
    private val autoHideRunnable = Runnable {
        if (isPlaying) {
            hideControls(animated = true)
        }
    }

    private val timeUpdateRunnable = object : Runnable {
        override fun run() {
            player?.let { p ->
                val current = p.currentPosition.toDouble() / 1000.0
                val duration = p.duration.coerceAtLeast(0L).toDouble() / 1000.0
                val buffered = p.bufferedPosition.coerceAtLeast(0L).toDouble() / 1000.0
                coordinator?.notifyEngineTime(current)
                if (Math.abs(buffered - lastReportedBuffer) >= 0.5 || (duration > 0.0 && buffered >= duration)) {
                    lastReportedBuffer = buffered
                    coordinator?.notifyEngineBuffer(buffered)
                }
                if (coordinator == null) {
                    bottomSection.updateTime(current, duration)
                    val pct = if (duration > 0.0) Math.min(100.0, (buffered / duration) * 100.0) else 0.0
                    bottomSection.updateBuffer(buffered, pct)
                }
            }
            if (isPlaying) {
                mainHandler.postDelayed(this, 250L) // 4 times a second
            }
        }
    }

    init {
        // Full bleed overlay
        layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)

        // 1. Top Section
        topSection = TopSection(context).apply {
            listener = this@ControlLayer
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.argb(165, 0, 0, 0), Color.TRANSPARENT)
            )
        }
        val topParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.TOP
        }
        addView(topSection, topParams)

        // 2. Center Section
        centerSection = CenterSection(context).apply {
            listener = this@ControlLayer
        }
        val centerParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER
        }
        addView(centerSection, centerParams)

        // 3. Bottom Section
        bottomSection = BottomSection(context).apply {
            listener = this@ControlLayer
            background = GradientDrawable(
                GradientDrawable.Orientation.BOTTOM_TOP,
                intArrayOf(Color.argb(185, 0, 0, 0), Color.TRANSPARENT)
            )
        }
        val bottomParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.BOTTOM
        }
        addView(bottomSection, bottomParams)

        // 4. Buffering Spinner
        bufferingSpinner = ProgressBar(context).apply {
            visibility = View.GONE
            isIndeterminate = true
        }
        val spinnerParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
            gravity = Gravity.CENTER
        }
        addView(bufferingSpinner, spinnerParams)

        // 5. Background Tap to Toggle
        setOnClickListener {
            toggleControls()
        }
    }

    fun attachPlayer(exoPlayer: ExoPlayer, playerCoordinator: com.player.core.PlayerStateCoordinator? = null) {
        this.player = exoPlayer
        this.coordinator = playerCoordinator
        this.isPlaying = exoPlayer.isPlaying
        centerSection.setPlaying(exoPlayer.isPlaying)
    }

    fun setPlaying(playing: Boolean, isEnded: Boolean = false) {
        this.isPlaying = playing
        this.isEnded = isEnded
        centerSection.setPlaying(playing, isEnded)
        if (playing) {
            startTimeUpdates()
            resetAutoHideTimer()
        } else {
            stopTimeUpdates()
            showControls(animated = true)
        }
    }

    fun setBuffering(buffering: Boolean) {
        bufferingSpinner.visibility = if (buffering) View.VISIBLE else View.GONE
    }

    // --- CenterSectionListener Callbacks ---

    override fun onPlayPauseClicked() {
        resetAutoHideTimer()
        coordinator?.let {
            it.requestTogglePlayPause()
        } ?: togglePlayPause()
    }

    override fun onRewindClicked(seconds: Int) {
        resetAutoHideTimer()
        coordinator?.let {
            it.requestStepSeek(-seconds.toDouble())
        } ?: run {
            player?.let {
                val target = (it.currentPosition - (seconds * 1000L)).coerceAtLeast(0L)
                it.seekTo(target)
            }
        }
    }

    override fun onForwardClicked(seconds: Int) {
        resetAutoHideTimer()
        coordinator?.let {
            it.requestStepSeek(seconds.toDouble())
        } ?: run {
            player?.let {
                val target = (it.currentPosition + (seconds * 1000L)).coerceAtMost(it.duration.coerceAtLeast(0L))
                it.seekTo(target)
            }
        }
    }

    fun togglePlayPause() {
        val p = player ?: return
        if (p.isPlaying) {
            p.pause()
        } else {
            if (p.playbackState == Player.STATE_ENDED || (p.duration > 0 && p.currentPosition >= p.duration)) {
                p.seekTo(0L)
            }
            p.play()
        }
    }

    // --- BottomSectionListener Callbacks (3-Phase C++ Scrub Engine) ---

    override fun onScrubStarted() {
        cancelAutoHideTimer()
        coordinator?.startScrubbing()
    }

    override fun onScrubbing(timeSeconds: Double) {
        coordinator?.scrubTo(timeSeconds)
    }

    override fun onScrubEnded(timeSeconds: Double) {
        coordinator?.let {
            it.endScrubbing(timeSeconds)
        } ?: run {
            player?.seekTo((timeSeconds * 1000.0).toLong())
        }
        if (isPlaying) {
            resetAutoHideTimer()
        }
    }

    override fun onFullscreenClicked() {
        resetAutoHideTimer()
        val target = !isFullscreen
        onFullscreenToggleRequested?.invoke(target)
    }

    fun setFullscreen(fullscreen: Boolean) {
        this.isFullscreen = fullscreen
        bottomSection.setFullscreen(fullscreen)
    }

    fun setShowFullscreenButton(show: Boolean) {
        bottomSection.setShowFullscreenButton(show)
    }

    fun setCustomIconsJson(jsonString: String?) {
        if (!jsonString.isNullOrEmpty()) {
            try {
                val json = org.json.JSONObject(jsonString)
                val map = mutableMapOf<String, String>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    map[k] = json.getString(k)
                }
                centerSection.customIcons = map
                bottomSection.customIcons = map
                map["back"]?.let { topSection.backButton.setIconSource(it, android.R.drawable.ic_menu_revert) }
            } catch (e: Exception) {}
        }
    }

    fun setAccentColor(colorHex: String?) {
        if (!colorHex.isNullOrEmpty()) {
            try {
                val c = Color.parseColor(colorHex)
                bottomSection.setAccentColor(c)
            } catch (e: Exception) {}
        }
    }

    fun setTrackColor(colorHex: String?) {
        if (!colorHex.isNullOrEmpty()) {
            try {
                val c = Color.parseColor(colorHex)
                bottomSection.setTrackColor(c)
            } catch (e: Exception) {}
        }
    }

    fun setBufferColor(colorHex: String?) {
        if (!colorHex.isNullOrEmpty()) {
            try {
                val c = Color.parseColor(colorHex)
                bottomSection.setBufferColor(c)
            } catch (e: Exception) {}
        }
    }

    fun setSkipInterval(seconds: Int) {
        if (seconds > 0) {
            centerSection.skipInterval = seconds
        }
    }

    fun setShowRewindButton(show: Boolean) {
        centerSection.setShowRewindButton(show)
    }

    fun setShowForwardButton(show: Boolean) {
        centerSection.setShowForwardButton(show)
    }

    fun setShowPlayPauseButton(show: Boolean) {
        centerSection.setShowPlayPauseButton(show)
    }

    fun setControlsVisible(visible: Boolean) {
        visibility = if (visible) View.VISIBLE else View.GONE
    }

    // --- TopSectionListener Callbacks ---

    override fun onBackClicked() {
        resetAutoHideTimer()
        if (isFullscreen) {
            onFullscreenToggleRequested?.invoke(false)
        }
    }

    override fun onCaptionsClicked() {
        cancelAutoHideTimer()
    }

    override fun onSettingsClicked() {
        cancelAutoHideTimer()
    }

    fun setTitle(title: String) {
        topSection.setTitle(title)
    }

    // --- Time Updater ---

    private fun startTimeUpdates() {
        stopTimeUpdates()
        mainHandler.post(timeUpdateRunnable)
    }

    private fun stopTimeUpdates() {
        mainHandler.removeCallbacks(timeUpdateRunnable)
    }

    // --- Visibility & Inactivity Auto-Hide Lifecycle ---

    fun toggleControls() {
        if (controlsVisible) {
            hideControls(animated = true)
        } else {
            showControls(animated = true)
        }
    }

    fun showControls(animated: Boolean) {
        cancelAutoHideTimer()
        controlsVisible = true

        topSection.visibility = View.VISIBLE
        centerSection.visibility = View.VISIBLE
        bottomSection.visibility = View.VISIBLE

        if (animated) {
            topSection.animate().alpha(1.0f).setDuration(250).start()
            centerSection.animate().alpha(1.0f).setDuration(250).start()
            bottomSection.animate().alpha(1.0f).setDuration(250).start()
        } else {
            topSection.alpha = 1.0f
            centerSection.alpha = 1.0f
            bottomSection.alpha = 1.0f
        }

        // Only auto-hide if currently playing
        if (isPlaying) {
            scheduleAutoHideTimer()
        }
    }

    fun hideControls(animated: Boolean) {
        cancelAutoHideTimer()
        controlsVisible = false

        if (animated) {
            topSection.animate().alpha(0.0f).setDuration(250).withEndAction {
                if (!controlsVisible) topSection.visibility = View.GONE
            }.start()
            centerSection.animate().alpha(0.0f).setDuration(250).withEndAction {
                if (!controlsVisible) centerSection.visibility = View.GONE
            }.start()
            bottomSection.animate().alpha(0.0f).setDuration(250).withEndAction {
                if (!controlsVisible) bottomSection.visibility = View.GONE
            }.start()
        } else {
            topSection.alpha = 0.0f
            centerSection.alpha = 0.0f
            bottomSection.alpha = 0.0f
            topSection.visibility = View.GONE
            centerSection.visibility = View.GONE
            bottomSection.visibility = View.GONE
        }
    }

    fun resetAutoHideTimer() {
        cancelAutoHideTimer()
        if (isPlaying) {
            scheduleAutoHideTimer()
        }
    }

    private fun scheduleAutoHideTimer() {
        cancelAutoHideTimer()
        if (autoHideTimeoutMs > 0L) {
            mainHandler.postDelayed(autoHideRunnable, autoHideTimeoutMs)
        }
    }

    private fun cancelAutoHideTimer() {
        mainHandler.removeCallbacks(autoHideRunnable)
    }

    private var safeAreaTopInset: Int = 0
    private var safeAreaBottomInset: Int = 0

    fun setSafeAreaInsets(topInset: Int, bottomInset: Int) {
        if (this.safeAreaTopInset == topInset && this.safeAreaBottomInset == bottomInset) return
        this.safeAreaTopInset = topInset
        this.safeAreaBottomInset = bottomInset
        if (width > 0 && height > 0) {
            val topH = topSection.measuredHeight
            topSection.layout(0, safeAreaTopInset, width, safeAreaTopInset + topH)
            val bottomH = bottomSection.measuredHeight
            bottomSection.layout(0, height - safeAreaBottomInset - bottomH, width, height - safeAreaBottomInset)
        }
        requestLayout()
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        val width = right - left
        val height = bottom - top

        val topH = topSection.measuredHeight
        topSection.layout(0, safeAreaTopInset, width, safeAreaTopInset + topH)

        val bottomH = bottomSection.measuredHeight
        bottomSection.layout(0, height - safeAreaBottomInset - bottomH, width, height - safeAreaBottomInset)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cancelAutoHideTimer()
        stopTimeUpdates()
    }
}
