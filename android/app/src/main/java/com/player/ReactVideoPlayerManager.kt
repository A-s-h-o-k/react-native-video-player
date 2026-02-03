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

    @ReactProp(name = "videoUrl")
    override fun setVideoUrl(view: ReactVideoPlayer, videoUrl: String?) {
        if(videoUrl == null) {
            return;
        }
        view.setUrl(videoUrl)
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

    }

    @ReactProp(name = "iconSize")
    override fun setIconSize(view: ReactVideoPlayer, value : Int) {

    }

    override fun getExportedCustomBubblingEventTypeConstants(): Map<String, Any> =
        mapOf(
            "onScriptLoaded" to
                    mapOf(
                        "phasedRegistrationNames" to
                                mapOf(
                                    "bubbled" to "onScriptLoaded",
                                    "captured" to "onScriptLoadedCapture"
                                )))
}