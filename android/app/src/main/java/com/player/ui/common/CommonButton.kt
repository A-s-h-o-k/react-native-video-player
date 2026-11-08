package com.player.ui.common

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.util.AttributeSet
import android.util.TypedValue
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.appcompat.widget.AppCompatImageButton
import androidx.core.view.ViewCompat

enum class CommonButtonSize(val dp: Int) {
    SMALL(36),
    MEDIUM(48),
    LARGE(72),
    CUSTOM(-1)
}

enum class CommonButtonStyle {
    TRANSLUCENT_CIRCLE, // Dark semi-transparent circle
    CLEAR,              // Icon only
    SOLID               // Opaque dark background
}

class CommonButton @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : AppCompatImageButton(context, attrs, defStyleAttr) {

    var buttonSize: CommonButtonSize = CommonButtonSize.MEDIUM
        set(value) {
            field = value
            applyStyleAndSize()
        }

    var buttonStyle: CommonButtonStyle = CommonButtonStyle.TRANSLUCENT_CIRCLE
        set(value) {
            field = value
            applyStyleAndSize()
        }

    var onTap: ((CommonButton) -> Unit)? = null

    init {
        // Minimum Material touch target (48dp)
        val minTargetPx = dpToPx(48)
        minimumWidth = minTargetPx
        minimumHeight = minTargetPx

        // TV Remote & Accessibility setup
        isFocusable = true
        isClickable = true
        scaleType = ScaleType.CENTER_INSIDE
        setColorFilter(Color.WHITE)

        setupInteractions()
        applyStyleAndSize()
    }

    private fun applyStyleAndSize() {
        // Background shape
        val backgroundDrawable = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            when (buttonStyle) {
                CommonButtonStyle.TRANSLUCENT_CIRCLE -> {
                    setColor(Color.parseColor("#8A1A1A1A")) // 55% dark
                }
                CommonButtonStyle.SOLID -> {
                    setColor(Color.parseColor("#E61A1A1A")) // 90% dark
                }
                CommonButtonStyle.CLEAR -> {
                    setColor(Color.TRANSPARENT)
                }
            }
        }

        // Wrap in Material Ripple
        val rippleColor = ColorStateList.valueOf(Color.parseColor("#4DFFFFFF"))
        background = RippleDrawable(rippleColor, backgroundDrawable, backgroundDrawable)
    }

    private fun setupInteractions() {
        // 1. Click callback
        setOnClickListener {
            onTap?.invoke(this)
        }

        // 2. Micro-animation on touch
        setOnTouchListener { v, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    v.animate().scaleX(0.92f).scaleY(0.92f).setDuration(100).start()
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    v.animate().scaleX(1.0f).scaleY(1.0f).setDuration(150).start()
                }
            }
            false // allow click listener to fire
        }

        // 3. Android TV & Fire TV D-pad Focus Listener
        setOnFocusChangeListener { v, hasFocus ->
            if (hasFocus) {
                // Scale up and highlight for TV screen 10-foot viewing
                v.animate()
                    .scaleX(1.18f)
                    .scaleY(1.18f)
                    .setDuration(200)
                    .start()
                (background as? RippleDrawable)?.findDrawableByLayerId(0)?.let {
                    (it as? GradientDrawable)?.setStroke(dpToPx(2), Color.WHITE)
                }
            } else {
                v.animate()
                    .scaleX(1.0f)
                    .scaleY(1.0f)
                    .setDuration(200)
                    .start()
                (background as? RippleDrawable)?.findDrawableByLayerId(0)?.let {
                    (it as? GradientDrawable)?.setStroke(0, Color.TRANSPARENT)
                }
            }
        }
    }

    // 4. TV Remote Hardware Keys (D-pad Center & Enter)
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_DPAD_CENTER || keyCode == KeyEvent.KEYCODE_ENTER) {
            performClick()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    /** Accessibility helper for TalkBack */
    fun configureAccessibility(label: String, hint: String? = null) {
        contentDescription = label
        hint?.let {
            ViewCompat.setStateDescription(this, it)
        }
    }

    /** Sets icon from local file, remote URL, drawable resource name, or system fallback */
    fun setIconSource(iconSource: String?, fallbackResId: Int) {
        if (!iconSource.isNullOrEmpty()) {
            if (iconSource.startsWith("file://") || iconSource.startsWith("/")) {
                val cleanPath = iconSource.removePrefix("file://")
                val bmp = android.graphics.BitmapFactory.decodeFile(cleanPath)
                if (bmp != null) {
                    setImageBitmap(bmp)
                    return
                }
            } else if (iconSource.startsWith("http://") || iconSource.startsWith("https://")) {
                Thread {
                    try {
                        val stream = java.net.URL(iconSource).openStream()
                        val bmp = android.graphics.BitmapFactory.decodeStream(stream)
                        if (bmp != null) {
                            post { setImageBitmap(bmp) }
                        }
                    } catch (e: Exception) {
                        post { setImageResource(fallbackResId) }
                    }
                }.start()
                return
            } else {
                val resId = context.resources.getIdentifier(iconSource, "drawable", context.packageName)
                if (resId != 0) {
                    setImageResource(resId)
                    return
                }
            }
        }
        setImageResource(fallbackResId)
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}
