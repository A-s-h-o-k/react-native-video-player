package com.player

import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.viewmanagers.VideoPlayerManagerDelegate;
import com.facebook.react.viewmanagers.VideoPlayerManagerInterface;
import com.facebook.react.uimanager.ViewManagerDelegate;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.uimanager.ThemedReactContext;

@ReactModule(name = ReactVideoPlayerManager.REACT_CLASS)
class ReactVideoPlayerManager(context: ReactApplicationContext): SimpleViewManager<ReactVideoPlayer>(), VideoPlayerManagerInterface<ReactVideoPlayer> {

    private val delegate: VideoPlayerManagerDelegate<ReactVideoPlayer, ReactVideoPlayerManager> = VideoPlayerManagerDelegate(this);

    override fun getDelegate(): ViewManagerDelegate<ReactVideoPlayer> = delegate

    override fun getName(): String = REACT_CLASS;

    override fun createViewInstance(context: ThemedReactContext): ReactVideoPlayer = ReactVideoPlayer(context)

    override fun onDropViewInstance(view: ReactVideoPlayer) {
        super.onDropViewInstance(view)
        view.cleanUp()
    }

    @ReactProp(name = "videoUrl")
    override fun setVideoUrl(view: ReactVideoPlayer, videoUrl: String?) {
        if(videoUrl == null) {
            return;
        }
        view.setUrl(videoUrl)
    }

    @ReactProp(name = "title")
    override fun setTitle(view: ReactVideoPlayer, value: String?) {
        view.setTitle(value ?: "")
    }

    @ReactProp(name = "headers")
    override fun setHeaders(view: ReactVideoPlayer, value: String?) {
        view.setHeaders(value)
    }

    @ReactProp(name = "drm")
    override fun setDrm(view: ReactVideoPlayer, value: String?) {
        view.setDrm(value)
    }

    companion object {
        const val REACT_CLASS = "VideoPlayer"
    }

    @ReactProp(name = "seekTo")
    override fun setSeekTo(view: ReactVideoPlayer, to: Int) {
        view.seekTo(to)
    }
    @ReactProp(name = "play")
    override fun setPlay(view: ReactVideoPlayer, value: Boolean) {
        if (value) {
            view.playVideo()
        } else {
            view.pauseVideo()
        }
    }

    @ReactProp(name = "iconSize")
    override fun setIconSize(view: ReactVideoPlayer, value : Int) {

    }

    @ReactProp(name = "resizeMode")
    override fun setResizeMode(view: ReactVideoPlayer, mode: String?) {
        view.setResizeMode(mode)
    }

    @ReactProp(name = "fullscreen")
    override fun setFullscreen(view: ReactVideoPlayer, value: Boolean) {
        view.setFullscreenProp(value)
    }

    @ReactProp(name = "showFullscreenButton")
    override fun setShowFullscreenButton(view: ReactVideoPlayer, value: Boolean) {
        view.setShowFullscreenButton(value)
    }

    @ReactProp(name = "autoAdjustSafeArea", defaultBoolean = true)
    override fun setAutoAdjustSafeArea(view: ReactVideoPlayer, value: Boolean) {
        view.setAutoAdjustSafeArea(value)
    }

    @ReactProp(name = "icons")
    override fun setIcons(view: ReactVideoPlayer, value: String?) {
        view.setIconsJson(value)
    }

    @ReactProp(name = "accentColor")
    override fun setAccentColor(view: ReactVideoPlayer, value: String?) {
        view.setAccentColor(value)
    }

    @ReactProp(name = "trackColor")
    override fun setTrackColor(view: ReactVideoPlayer, value: String?) {
        view.setTrackColor(value)
    }

    @ReactProp(name = "bufferColor")
    override fun setBufferColor(view: ReactVideoPlayer, value: String?) {
        view.setBufferColor(value)
    }

    @ReactProp(name = "skipInterval", defaultInt = 15)
    override fun setSkipInterval(view: ReactVideoPlayer, value: Int) {
        view.setSkipInterval(value)
    }

    @ReactProp(name = "showRewindButton", defaultBoolean = true)
    override fun setShowRewindButton(view: ReactVideoPlayer, value: Boolean) {
        view.setShowRewindButton(value)
    }

    @ReactProp(name = "showForwardButton", defaultBoolean = true)
    override fun setShowForwardButton(view: ReactVideoPlayer, value: Boolean) {
        view.setShowForwardButton(value)
    }

    @ReactProp(name = "showPlayPauseButton", defaultBoolean = true)
    override fun setShowPlayPauseButton(view: ReactVideoPlayer, value: Boolean) {
        view.setShowPlayPauseButton(value)
    }

    @ReactProp(name = "autoHideTimeout", defaultInt = 5000)
    override fun setAutoHideTimeout(view: ReactVideoPlayer, value: Int) {
        view.setAutoHideTimeout(value)
    }

    @ReactProp(name = "controls", defaultBoolean = true)
    override fun setControls(view: ReactVideoPlayer, value: Boolean) {
        view.setControlsVisible(value)
    }

    override fun getExportedCustomBubblingEventTypeConstants(): Map<String, Any> =
        mapOf(
            "onScriptLoaded" to
                    mapOf(
                        "phasedRegistrationNames" to
                                mapOf(
                                    "bubbled" to "onScriptLoaded",
                                    "captured" to "onScriptLoadedCapture"
                                )),
            "onFullscreenChange" to
                    mapOf(
                        "phasedRegistrationNames" to
                                mapOf(
                                    "bubbled" to "onFullscreenChange",
                                    "captured" to "onFullscreenChangeCapture"
                                )))
}