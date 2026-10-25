package com.player

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import com.facebook.react.uimanager.ViewManager

class ReactVideoPlayerPackage : BaseReactPackage() {
    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
        return listOf(
            ReactVideoPlayerManager(reactContext)
        )
    }

    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
        when (name) {
            ReactVideoPlayerManager.REACT_CLASS -> ReactVideoPlayerManager(reactContext)
        }
        return null
    }

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider = ReactModuleInfoProvider {
        mapOf(
            ReactVideoPlayerManager.REACT_CLASS to ReactModuleInfo(
                name = ReactVideoPlayerManager.REACT_CLASS,
                className = ReactVideoPlayerManager.REACT_CLASS,
                canOverrideExistingModule = false,
                needsEagerInit = false,
                isCxxModule = false,
                isTurboModule = true,
            )
        )
    }
}