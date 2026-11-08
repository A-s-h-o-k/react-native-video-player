package com.player.subtitles

/**
 * Immutable model representing an available subtitle / closed-caption track.
 */
data class SubtitleTrack(
    val id: String,
    val language: String,
    val label: String,
    val isSelected: Boolean
)
