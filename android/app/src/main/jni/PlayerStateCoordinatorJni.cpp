//
//  PlayerStateCoordinatorJni.cpp
//  Player (Android JNI Bridge)
//
//  JNI bridge connecting Kotlin UI & ExoPlayer to the shared pure C++ PlayerStateCoordinator.
//

#include <jni.h>
#include <string>
#include <memory>
#include <mutex>
#include <android/log.h>

#include "PlayerStateCoordinator.hpp"
#include "IPlaybackEngineBridge.hpp"
#include "IPlayerStateObserver.hpp"

#ifdef LOG_TAG
#undef LOG_TAG
#endif
#define LOG_TAG "PlayerStateCoordinatorJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static JavaVM* g_jvm = nullptr;

static thread_local struct JNIThreadDetacher {
    JavaVM* vm = nullptr;
    ~JNIThreadDetacher() {
        if (vm) vm->DetachCurrentThread();
    }
} sDetacher;

static void initJavaVM(JNIEnv* env) {
    if (!g_jvm) {
        env->GetJavaVM(&g_jvm);
    }
}

static JNIEnv* getEnv() {
    if (!g_jvm) return nullptr;
    JNIEnv* env = nullptr;
    jint res = g_jvm->GetEnv((void**)&env, JNI_VERSION_1_6);
    if (res == JNI_EDETACHED) {
        if (g_jvm->AttachCurrentThread(&env, nullptr) != 0) {
            LOGE("Failed to attach current thread to JVM");
            return nullptr;
        }
        sDetacher.vm = g_jvm;
    }
    return env;
}

// 1. AndroidPlaybackEngineBridge: Implements IPlaybackEngineBridge, calls Kotlin methods on BasePlayer
class AndroidPlaybackEngineBridge : public PlayerCore::IPlaybackEngineBridge {
public:
    AndroidPlaybackEngineBridge(JNIEnv* env, jobject callback) {
        initJavaVM(env);
        callback_ = env->NewGlobalRef(callback);
        jclass clazz = env->GetObjectClass(callback);
        playMethod_ = env->GetMethodID(clazz, "executePlay", "()V");
        pauseMethod_ = env->GetMethodID(clazz, "executePause", "()V");
        seekMethod_ = env->GetMethodID(clazz, "executeSeek", "(D)V");
        rateMethod_ = env->GetMethodID(clazz, "executePlaybackRate", "(F)V");
        volumeMethod_ = env->GetMethodID(clazz, "executeVolume", "(F)V");
        muteMethod_ = env->GetMethodID(clazz, "executeMute", "(Z)V");
        env->DeleteLocalRef(clazz);
    }

    ~AndroidPlaybackEngineBridge() override {
        JNIEnv* env = getEnv();
        if (env && callback_) {
            env->DeleteGlobalRef(callback_);
            callback_ = nullptr;
        }
    }

    void executePlay() override {
        JNIEnv* env = getEnv();
        if (env && callback_ && playMethod_) {
            env->CallVoidMethod(callback_, playMethod_);
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void executePause() override {
        JNIEnv* env = getEnv();
        if (env && callback_ && pauseMethod_) {
            env->CallVoidMethod(callback_, pauseMethod_);
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void executeSeek(double seconds) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && seekMethod_) {
            env->CallVoidMethod(callback_, seekMethod_, static_cast<jdouble>(seconds));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void executePlaybackRate(float rate) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && rateMethod_) {
            env->CallVoidMethod(callback_, rateMethod_, static_cast<jfloat>(rate));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void executeVolume(float volume) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && volumeMethod_) {
            env->CallVoidMethod(callback_, volumeMethod_, static_cast<jfloat>(volume));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void executeMute(bool muted) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && muteMethod_) {
            env->CallVoidMethod(callback_, muteMethod_, static_cast<jboolean>(muted));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

private:
    jobject callback_ = nullptr;
    jmethodID playMethod_ = nullptr;
    jmethodID pauseMethod_ = nullptr;
    jmethodID seekMethod_ = nullptr;
    jmethodID rateMethod_ = nullptr;
    jmethodID volumeMethod_ = nullptr;
    jmethodID muteMethod_ = nullptr;
};

// 2. AndroidStateObserverBridge: Implements IPlayerStateObserver, notifies Kotlin ControlLayer
class AndroidStateObserverBridge : public PlayerCore::IPlayerStateObserver {
public:
    AndroidStateObserverBridge(JNIEnv* env, jobject callback) {
        initJavaVM(env);
        callback_ = env->NewGlobalRef(callback);
        jclass clazz = env->GetObjectClass(callback);
        stateMethod_ = env->GetMethodID(clazz, "onStateChanged", "(II)V");
        timeMethod_ = env->GetMethodID(clazz, "onTimeUpdated", "(DD)V");
        bufferMethod_ = env->GetMethodID(clazz, "onBufferUpdated", "(DD)V");
        muteMethod_ = env->GetMethodID(clazz, "onMuteChanged", "(ZF)V");
        rateMethod_ = env->GetMethodID(clazz, "onPlaybackRateChanged", "(F)V");
        errorMethod_ = env->GetMethodID(clazz, "onError", "(ILjava/lang/String;)V");
        env->DeleteLocalRef(clazz);
    }

    ~AndroidStateObserverBridge() override {
        JNIEnv* env = getEnv();
        if (env && callback_) {
            env->DeleteGlobalRef(callback_);
            callback_ = nullptr;
        }
    }

    void onStateChanged(PlayerCore::PlaybackState newState, PlayerCore::PlaybackState oldState) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && stateMethod_) {
            env->CallVoidMethod(callback_, stateMethod_, static_cast<jint>(newState), static_cast<jint>(oldState));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void onTimeUpdated(double currentTime, double duration) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && timeMethod_) {
            env->CallVoidMethod(callback_, timeMethod_, static_cast<jdouble>(currentTime), static_cast<jdouble>(duration));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void onBufferUpdated(double bufferedTime, double percentage) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && bufferMethod_) {
            env->CallVoidMethod(callback_, bufferMethod_, static_cast<jdouble>(bufferedTime), static_cast<jdouble>(percentage));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void onMuteChanged(bool isMuted, float volume) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && muteMethod_) {
            env->CallVoidMethod(callback_, muteMethod_, static_cast<jboolean>(isMuted), static_cast<jfloat>(volume));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void onPlaybackRateChanged(float rate) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && rateMethod_) {
            env->CallVoidMethod(callback_, rateMethod_, static_cast<jfloat>(rate));
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

    void onError(int errorCode, const std::string& message) override {
        JNIEnv* env = getEnv();
        if (env && callback_ && errorMethod_) {
            jstring jmsg = env->NewStringUTF(message.c_str());
            if (!jmsg) {
                env->ExceptionClear();
                return;
            }
            env->CallVoidMethod(callback_, errorMethod_, static_cast<jint>(errorCode), jmsg);
            env->DeleteLocalRef(jmsg);
            if (env->ExceptionCheck()) {
                env->ExceptionDescribe();
                env->ExceptionClear();
                return;
            }
        }
    }

private:
    jobject callback_ = nullptr;
    jmethodID stateMethod_ = nullptr;
    jmethodID timeMethod_ = nullptr;
    jmethodID bufferMethod_ = nullptr;
    jmethodID muteMethod_ = nullptr;
    jmethodID rateMethod_ = nullptr;
    jmethodID errorMethod_ = nullptr;
};

// Container linking C++ coordinator, engine bridge, and observer bridge together
struct AndroidCoordinatorContext {
    std::unique_ptr<PlayerCore::PlayerStateCoordinator> coordinator;
    std::unique_ptr<AndroidPlaybackEngineBridge> engineBridge;
    std::shared_ptr<AndroidStateObserverBridge> observer;
};

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeCreate(
        JNIEnv *env,
        jobject /* this */,
        jobject engineBridgeCallback,
        jobject observerCallback) {
    initJavaVM(env);

    auto context = new AndroidCoordinatorContext();
    context->coordinator = std::make_unique<PlayerCore::PlayerStateCoordinator>();

    if (engineBridgeCallback != nullptr) {
        context->engineBridge = std::make_unique<AndroidPlaybackEngineBridge>(env, engineBridgeCallback);
        context->coordinator->setEngineBridge(context->engineBridge.get());
    }

    if (observerCallback != nullptr) {
        context->observer = std::make_shared<AndroidStateObserverBridge>(env, observerCallback);
        context->coordinator->addObserver(context->observer);
    }

    LOGI("PlayerStateCoordinator created: %p", context);
    return reinterpret_cast<jlong>(context);
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeDestroy(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    LOGI("PlayerStateCoordinator destroying: %p", context);
    delete context;
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeRequestPlay(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->requestPlay();
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeRequestPause(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->requestPause();
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeRequestTogglePlayPause(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->requestTogglePlayPause();
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeRequestSeek(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle,
        jdouble seconds) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->requestSeek(seconds);
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeRequestStepSeek(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle,
        jdouble deltaSeconds) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->requestStepSeek(deltaSeconds);
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeStartScrubbing(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->startScrubbing();
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeScrubTo(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle,
        jdouble seconds) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->scrubTo(seconds);
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeEndScrubbing(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle,
        jdouble seconds) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->endScrubbing(seconds);
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeNotifyEngineState(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle,
        jint state) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->notifyEngineState(static_cast<PlayerCore::PlaybackState>(state));
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeNotifyEngineTime(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle,
        jdouble currentTime) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->notifyEngineTime(currentTime);
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeNotifyEngineDuration(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle,
        jdouble duration) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->notifyEngineDuration(duration);
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeNotifyEngineBuffer(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle,
        jdouble bufferedTime) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    context->coordinator->notifyEngineBuffer(bufferedTime);
}

JNIEXPORT void JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeNotifyEngineError(
        JNIEnv *env,
        jobject /* this */,
        jlong handle,
        jint errorCode,
        jstring message) {
    if (handle == 0) return;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    const char* nativeMsg = env->GetStringUTFChars(message, nullptr);
    context->coordinator->notifyEngineError(errorCode, nativeMsg ? nativeMsg : "");
    if (nativeMsg) env->ReleaseStringUTFChars(message, nativeMsg);
}

JNIEXPORT jint JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeGetPlaybackState(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return 0;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    return static_cast<jint>(context->coordinator->getSnapshot().state);
}

JNIEXPORT jdouble JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeGetCurrentTime(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return 0.0;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    return context->coordinator->getSnapshot().currentTime;
}

JNIEXPORT jdouble JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeGetDuration(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return 0.0;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    return context->coordinator->getSnapshot().duration;
}

JNIEXPORT jboolean JNICALL
Java_com_player_core_PlayerStateCoordinator_nativeIsScrubbing(
        JNIEnv * /* env */,
        jobject /* this */,
        jlong handle) {
    if (handle == 0) return JNI_FALSE;
    auto context = reinterpret_cast<AndroidCoordinatorContext*>(handle);
    return context->coordinator->getSnapshot().isScrubbing ? JNI_TRUE : JNI_FALSE;
}

} // extern "C"
