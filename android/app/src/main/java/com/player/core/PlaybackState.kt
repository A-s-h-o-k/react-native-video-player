package com.player.core

/**
 * Mirror of C++ PlayerCore::PlaybackState enum in PlayerTypes.hpp
 */
enum class PlaybackState {
    Idle,       // 0
    Loading,    // 1
    Ready,      // 2
    Playing,    // 3
    Paused,     // 4
    Buffering,  // 5
    Ended,      // 6
    Error;      // 7

    companion object {
        fun fromInt(value: Int): PlaybackState {
            val all = entries
            return if (value in all.indices) all[value] else Idle
        }
    }
}
