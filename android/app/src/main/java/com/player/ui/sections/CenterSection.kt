package com.player.ui.sections

import android.content.Context
import android.util.AttributeSet
import android.view.Gravity
import android.widget.LinearLayout
import com.player.R
import com.player.ui.common.CommonButton
import com.player.ui.common.CommonButtonSize
import com.player.ui.common.CommonButtonStyle

interface CenterSectionListener {
    fun onPlayPauseClicked()
    fun onRewindClicked(seconds: Int = 15)
    fun onForwardClicked(seconds: Int = 15)
}

class CenterSection @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    val backwardButton: CommonButton
    val playButton: CommonButton
    val forwardButton: CommonButton

    var listener: CenterSectionListener? = null
    var skipInterval: Int = 15
        set(value) {
            field = if (value > 0) value else 15
            updateRewindButtonIcon()
            updateForwardButtonIcon()
        }

    var customIcons: Map<String, String>? = null
        set(value) {
            field = value
            updateRewindButtonIcon()
            updateForwardButtonIcon()
            setPlaying(isPlayingState, isEndedState)
        }

    private var isPlayingState: Boolean = false
    private var isEndedState: Boolean = false

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER

        // 1. Rewind Button
        backwardButton = CommonButton(context).apply {
            buttonSize = CommonButtonSize.MEDIUM
            buttonStyle = CommonButtonStyle.TRANSLUCENT_CIRCLE
            setImageResource(android.R.drawable.ic_media_rew)
            configureAccessibility("Rewind $skipInterval seconds", "Seeks backward by $skipInterval seconds")
            onTap = {
                listener?.onRewindClicked(skipInterval)
            }
        }

        // 2. Play / Pause Button (Large)
        playButton = CommonButton(context).apply {
            buttonSize = CommonButtonSize.LARGE
            buttonStyle = CommonButtonStyle.TRANSLUCENT_CIRCLE
            setImageResource(android.R.drawable.ic_media_play)
            configureAccessibility("Play", "Starts video playback")
            onTap = {
                listener?.onPlayPauseClicked()
            }
        }

        // 3. Fast Forward Button
        forwardButton = CommonButton(context).apply {
            buttonSize = CommonButtonSize.MEDIUM
            buttonStyle = CommonButtonStyle.TRANSLUCENT_CIRCLE
            setImageResource(android.R.drawable.ic_media_ff)
            configureAccessibility("Fast forward $skipInterval seconds", "Seeks forward by $skipInterval seconds")
            onTap = {
                listener?.onForwardClicked(skipInterval)
            }
        }

        val mediumParams = LayoutParams(dpToPx(48), dpToPx(48)).apply {
            setMargins(dpToPx(16), 0, dpToPx(16), 0)
        }
        val largeParams = LayoutParams(dpToPx(72), dpToPx(72)).apply {
            setMargins(dpToPx(16), 0, dpToPx(16), 0)
        }

        addView(backwardButton, mediumParams)
        addView(playButton, largeParams)
        addView(forwardButton, mediumParams)
    }

    fun setShowRewindButton(show: Boolean) {
        backwardButton.visibility = if (show) VISIBLE else GONE
    }

    fun setShowForwardButton(show: Boolean) {
        forwardButton.visibility = if (show) VISIBLE else GONE
    }

    fun setShowPlayPauseButton(show: Boolean) {
        playButton.visibility = if (show) VISIBLE else GONE
    }

    private fun updateRewindButtonIcon() {
        backwardButton.setIconSource(customIcons?.get("rewind"), android.R.drawable.ic_media_rew)
        backwardButton.configureAccessibility("Rewind $skipInterval seconds", "Seeks backward by $skipInterval seconds")
    }

    private fun updateForwardButtonIcon() {
        forwardButton.setIconSource(customIcons?.get("forward"), android.R.drawable.ic_media_ff)
        forwardButton.configureAccessibility("Fast forward $skipInterval seconds", "Seeks forward by $skipInterval seconds")
    }

    fun setPlaybackEnded(ended: Boolean) {
        setPlaying(playing = false, isEnded = ended)
    }

    fun setPlaying(playing: Boolean, isEnded: Boolean = false) {
        isPlayingState = playing
        isEndedState = isEnded
        if (isEnded) {
            playButton.setIconSource(customIcons?.get("replay"), R.drawable.ic_replay)
            playButton.configureAccessibility("Replay", "Replays video from the beginning")
        } else if (playing) {
            playButton.setIconSource(customIcons?.get("pause"), android.R.drawable.ic_media_pause)
            playButton.configureAccessibility("Pause", "Pauses video playback")
        } else {
            playButton.setIconSource(customIcons?.get("play"), android.R.drawable.ic_media_play)
            playButton.configureAccessibility("Play", "Resumes video playback")
        }
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
