package com.player.subtitles

import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer

interface SubtitleListener {
    fun onSubtitlesChanged(availableTracks: List<SubtitleTrack>, activeTrack: SubtitleTrack?)
}

/**
 * Dedicated Subtitle / Closed-Caption manager for Android & Android TV.
 *
 * Interrogates ExoPlayer text track groups, maintains track selection state,
 * and decouples subtitle logic from the core player and UI views.
 */
@OptIn(UnstableApi::class)
class SubtitleManager(private val player: ExoPlayer) {

    var listener: SubtitleListener? = null
    private val availableTracks = mutableListOf<SubtitleTrack>()
    private var activeTrack: SubtitleTrack? = null

    /**
     * Inspects updated player tracks and extracts all legible text tracks.
     */
    fun onTracksChanged(tracks: Tracks) {
        availableTracks.clear()
        activeTrack = null

        for (group in tracks.groups) {
            if (group.type == C.TRACK_TYPE_TEXT) {
                for (i in 0 until group.length) {
                    val format = group.getTrackFormat(i)
                    val isSelected = group.isTrackSelected(i)
                    val lang = format.language ?: "und"
                    val label = format.label ?: format.language ?: "Subtitle ${availableTracks.size + 1}"
                    val id = format.id ?: "$lang-$i"

                    val track = SubtitleTrack(
                        id = id,
                        language = lang,
                        label = label,
                        isSelected = isSelected
                    )
                    availableTracks.add(track)
                    if (isSelected) {
                        activeTrack = track
                    }
                }
            }
        }

        listener?.onSubtitlesChanged(availableTracks.toList(), activeTrack)
    }

    /**
     * Selects a subtitle track by its language code, or disables subtitles if null.
     */
    fun selectLanguage(languageCode: String?) {
        val currentParams = player.trackSelectionParameters
        if (languageCode == null) {
            player.trackSelectionParameters = currentParams.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                .build()
        } else {
            player.trackSelectionParameters = currentParams.buildUpon()
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
                .setPreferredTextLanguage(languageCode)
                .build()
        }
    }

    /**
     * Toggles the first available subtitle track if none is selected, or turns them off if active.
     */
    fun toggleSubtitles(): Boolean {
        if (availableTracks.isEmpty()) return false

        return if (activeTrack != null) {
            selectLanguage(null)
            false
        } else {
            val target = availableTracks.firstOrNull()?.language ?: "en"
            selectLanguage(target)
            true
        }
    }

    fun getAvailableSubtitles(): List<SubtitleTrack> = availableTracks.toList()
    fun getActiveSubtitle(): SubtitleTrack? = activeTrack
}
