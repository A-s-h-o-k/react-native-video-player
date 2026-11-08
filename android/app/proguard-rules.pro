# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.3.3/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.

# React Native & Fabric Component Props
-keep class com.player.** { *; }
-keepclassmembers class * {
    @com.facebook.react.uimanager.annotations.ReactProp <methods>;
    @com.facebook.react.uimanager.annotations.ReactPropGroup <methods>;
}

# JNI & C++ Bridge
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class com.player.core.PlayerStateCoordinator { *; }

# Media3 ExoPlayer
-keep class androidx.media3.** { *; }
