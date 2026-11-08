package com.player.ui.sections

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.util.AttributeSet
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import com.player.ui.common.CommonButton
import com.player.ui.common.CommonButtonSize
import com.player.ui.common.CommonButtonStyle

interface BottomSectionListener {
    fun onScrubStarted()
    fun onScrubbing(timeSeconds: Double)
    fun onScrubEnded(timeSeconds: Double)
    fun onFullscreenClicked()
}

class BottomSection @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    val currentTimeLabel: TextView
    val seekBar: SeekBar
    val durationLabel: TextView
    val fullscreenButton: CommonButton

    var listener: BottomSectionListener? = null
    var isScrubbing: Boolean = false
        private set

    private var isFullscreenState: Boolean = false
    var customIcons: Map<String, String>? = null
        set(value) {
            field = value
            loadThumb(value?.get("sliderThumb"))
            setFullscreen(isFullscreenState)
        }

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dpToPx(16), 0, dpToPx(16), dpToPx(8))

        // 1. Current Elapsed Time Label
        currentTimeLabel = TextView(context).apply {
            setTextColor(Color.WHITE)
            textSize = 12f
            typeface = Typeface.MONOSPACE
            text = "00:00"
            gravity = Gravity.CENTER
        }

        // 2. High-Precision 60fps Scrubber SeekBar
        seekBar = SeekBar(context).apply {
            max = 1000
            progress = 0
            isFocusable = true
            contentDescription = "Video timeline scrubber"
            progressTintList = android.content.res.ColorStateList.valueOf(Color.WHITE)
            thumbTintList = android.content.res.ColorStateList.valueOf(Color.WHITE)
            secondaryProgressTintList = android.content.res.ColorStateList.valueOf(Color.argb(100, 255, 255, 255))
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onStartTrackingTouch(sb: SeekBar?) {
                    isScrubbing = true
                    listener?.onScrubStarted()
                }

                override fun onProgressChanged(sb: SeekBar?, progress: Int, fromUser: Boolean) {
                    if (fromUser) {
                        val seconds = progress.toDouble() / 1000.0
                        currentTimeLabel.text = formatTime(seconds)
                        listener?.onScrubbing(seconds)
                    }
                }

                override fun onStopTrackingTouch(sb: SeekBar?) {
                    isScrubbing = false
                    val seconds = (sb?.progress ?: 0).toDouble() / 1000.0
                    listener?.onScrubEnded(seconds)
                }
            })
        }

        // 3. Duration Label
        durationLabel = TextView(context).apply {
            setTextColor(Color.argb(180, 255, 255, 255))
            textSize = 12f
            typeface = Typeface.MONOSPACE
            text = "00:00"
            gravity = Gravity.CENTER
        }

        // 4. Fullscreen Button (Small CommonButton)
        fullscreenButton = CommonButton(context).apply {
            buttonSize = CommonButtonSize.SMALL
            buttonStyle = CommonButtonStyle.TRANSLUCENT_CIRCLE
            setImageResource(android.R.drawable.ic_menu_crop)
            configureAccessibility("Fullscreen", "Toggles fullscreen display")
            visibility = View.GONE
            onTap = {
                listener?.onFullscreenClicked()
            }
        }

        // Layout Params
        val labelParams = LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT)
        val seekParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1.0f).apply {
            setMargins(dpToPx(8), 0, dpToPx(8), 0)
        }
        val btnParams = LayoutParams(dpToPx(36), dpToPx(36)).apply {
            setMargins(dpToPx(8), 0, 0, 0)
        }

        addView(currentTimeLabel, labelParams)
        addView(seekBar, seekParams)
        addView(durationLabel, labelParams)
        addView(fullscreenButton, btnParams)
    }

    fun updateTime(currentTimeSeconds: Double, durationSeconds: Double) {
        if (!isScrubbing) {
            if (durationSeconds > 0.0) {
                seekBar.max = (durationSeconds * 1000.0).toInt()
                seekBar.progress = (currentTimeSeconds * 1000.0).toInt()
            } else {
                seekBar.max = 1000
                seekBar.progress = 0
            }
            currentTimeLabel.text = formatTime(currentTimeSeconds)
        }
        durationLabel.text = formatTime(durationSeconds)
    }

    fun updateBuffer(bufferedTimeSeconds: Double, percentage: Double = 0.0) {
        if (seekBar.max > 0) {
            val target = (bufferedTimeSeconds * 1000.0).toInt().coerceIn(0, seekBar.max)
            seekBar.secondaryProgress = target
        } else if (percentage in 0.0..100.0) {
            seekBar.secondaryProgress = percentage.toInt()
        }
    }

    fun setFullscreen(isFullscreen: Boolean) {
        isFullscreenState = isFullscreen
        if (isFullscreen) {
            fullscreenButton.setIconSource(customIcons?.get("fullscreenExit"), android.R.drawable.ic_menu_close_clear_cancel)
            fullscreenButton.configureAccessibility("Exit fullscreen", "Exits fullscreen display")
        } else {
            fullscreenButton.setIconSource(customIcons?.get("fullscreenEnter"), android.R.drawable.ic_menu_crop)
            fullscreenButton.configureAccessibility("Fullscreen", "Toggles fullscreen display")
        }
    }

    fun setShowFullscreenButton(show: Boolean) {
        fullscreenButton.visibility = if (show) View.VISIBLE else View.GONE
    }

    fun setAccentColor(color: Int) {
        seekBar.thumbTintList = ColorStateList.valueOf(color)
        seekBar.progressTintList = ColorStateList.valueOf(color)
    }

    fun setTrackColor(color: Int) {
        seekBar.progressBackgroundTintList = ColorStateList.valueOf(color)
    }

    fun setBufferColor(color: Int) {
        seekBar.secondaryProgressTintList = ColorStateList.valueOf(color)
    }

    private fun loadThumb(thumbSource: String?) {
        if (!thumbSource.isNullOrEmpty()) {
            if (thumbSource.startsWith("file://") || thumbSource.startsWith("/")) {
                val cleanPath = thumbSource.removePrefix("file://")
                val bmp = android.graphics.BitmapFactory.decodeFile(cleanPath)
                if (bmp != null) {
                    seekBar.thumb = android.graphics.drawable.BitmapDrawable(resources, bmp)
                    return
                }
            } else if (thumbSource.startsWith("http://") || thumbSource.startsWith("https://")) {
                Thread {
                    try {
                        val stream = java.net.URL(thumbSource).openStream()
                        val bmp = android.graphics.BitmapFactory.decodeStream(stream)
                        if (bmp != null) {
                            post { seekBar.thumb = android.graphics.drawable.BitmapDrawable(resources, bmp) }
                        }
                    } catch (e: Exception) {}
                }.start()
                return
            } else {
                val resId = context.resources.getIdentifier(thumbSource, "drawable", context.packageName)
                if (resId != 0) {
                    seekBar.thumb = androidx.core.content.ContextCompat.getDrawable(context, resId)
                    return
                }
            }
        }
    }

    private fun formatTime(totalSeconds: Double): String {
        if (totalSeconds.isNaN() || totalSeconds < 0.0) {
            return "00:00"
        }
        val seconds = Math.round(totalSeconds).toInt()
        val hours = seconds / 3600
        val minutes = (seconds % 3600) / 60
        val secs = seconds % 60

        return if (hours > 0) {
            String.format("%02d:%02d:%02d", hours, minutes, secs)
        } else {
            String.format("%02d:%02d", minutes, secs)
        }
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
