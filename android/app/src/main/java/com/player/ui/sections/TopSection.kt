package com.player.ui.sections

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.text.TextUtils
import android.util.AttributeSet
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import com.player.ui.common.CommonButton
import com.player.ui.common.CommonButtonSize
import com.player.ui.common.CommonButtonStyle

interface TopSectionListener {
    fun onBackClicked()
    fun onCaptionsClicked()
    fun onSettingsClicked()
}

class TopSection @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    val backButton: CommonButton
    val titleLabel: TextView
    val captionsButton: CommonButton
    val settingsButton: CommonButton

    var listener: TopSectionListener? = null

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dpToPx(16), dpToPx(12), dpToPx(16), dpToPx(12))

        // 1. Navigation Back Button (Small CommonButton)
        backButton = CommonButton(context).apply {
            buttonSize = CommonButtonSize.SMALL
            buttonStyle = CommonButtonStyle.TRANSLUCENT_CIRCLE
            setImageResource(android.R.drawable.ic_menu_revert)
            configureAccessibility("Back", "Navigates back or closes the video player")
            onTap = {
                listener?.onBackClicked()
            }
        }

        // 2. Video Title Label
        titleLabel = TextView(context).apply {
            setTextColor(Color.WHITE)
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setShadowLayer(4f, 0f, 2f, Color.argb(128, 0, 0, 0))
            text = ""
        }

        // 3. Captions Button
        captionsButton = CommonButton(context).apply {
            buttonSize = CommonButtonSize.SMALL
            buttonStyle = CommonButtonStyle.TRANSLUCENT_CIRCLE
            setImageResource(android.R.drawable.ic_menu_info_details)
            configureAccessibility("Audio and subtitles", "Selects audio tracks and subtitles")
            onTap = {
                listener?.onCaptionsClicked()
            }
        }

        // 4. Settings Button
        settingsButton = CommonButton(context).apply {
            buttonSize = CommonButtonSize.SMALL
            buttonStyle = CommonButtonStyle.TRANSLUCENT_CIRCLE
            setImageResource(android.R.drawable.ic_menu_preferences)
            configureAccessibility("Settings", "Adjusts playback speed and video quality")
            onTap = {
                listener?.onSettingsClicked()
            }
        }

        val btnParams = LayoutParams(dpToPx(36), dpToPx(36))
        val titleParams = LayoutParams(0, LayoutParams.WRAP_CONTENT, 1.0f).apply {
            setMargins(dpToPx(12), 0, dpToPx(12), 0)
        }
        val settingsParams = LayoutParams(dpToPx(36), dpToPx(36)).apply {
            setMargins(dpToPx(8), 0, 0, 0)
        }

        addView(backButton, btnParams)
        addView(titleLabel, titleParams)
        addView(captionsButton, btnParams)
        addView(settingsButton, settingsParams)
    }

    fun setTitle(title: String) {
        titleLabel.text = title
    }

    private fun dpToPx(dp: Int): Int {
        return (dp * resources.displayMetrics.density).toInt()
    }
}
