package com.player.ui

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.ProgressBar
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

    val topSection: TopSection
    val centerSection: CenterSection
    val bottomSection: BottomSection
    val bufferingSpinner: ProgressBar

    private var controlsVisible: Boolean = true
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
                coordinator?.notifyEngineTime(current)
                if (coordinator == null) {
                    bottomSection.updateTime(current, duration)
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

    fun setPlaying(playing: Boolean) {
        this.isPlaying = playing
        centerSection.setPlaying(playing)
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
    }

    // --- TopSectionListener Callbacks ---

    override fun onBackClicked() {
        resetAutoHideTimer()
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
            topSection.animate().alpha(0.0f).setDuration(250).start()
            centerSection.animate().alpha(0.0f).setDuration(250).start()
            bottomSection.animate().alpha(0.0f).setDuration(250).start()
        } else {
            topSection.alpha = 0.0f
            centerSection.alpha = 0.0f
            bottomSection.alpha = 0.0f
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
        mainHandler.postDelayed(autoHideRunnable, 5000L)
    }

    private fun cancelAutoHideTimer() {
        mainHandler.removeCallbacks(autoHideRunnable)
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cancelAutoHideTimer()
        stopTimeUpdates()
    }
}
