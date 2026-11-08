package com.player.metadata

import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaMetadata
import androidx.media3.common.util.UnstableApi
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.util.Locale

/**
 * Dedicated metadata resolver for Android & Android TV.
 *
 * Implements a 3-tier hierarchy:
 * 1. Explicit prop title (developer override)
 * 2. Embedded stream/container metadata (MP4 ©nam, ID3 TIT2, ICY stream title)
 * 3. Clean URL slug extraction with camelCase / kebab-case / snake_case sanitization
 */
@OptIn(UnstableApi::class)
class MediaMetadataResolver {

    /**
     * Resolves the best available metadata given the current state.
     */
    fun resolve(
        explicitTitle: String?,
        streamMetadata: MediaMetadata?,
        url: String?
    ): MediaMetadataInfo {
        val streamTitle = streamMetadata?.title?.toString()?.trim()
        val streamArtist = streamMetadata?.artist?.toString()?.trim()
        val artworkBytes = streamMetadata?.artworkData

        val finalTitle = when {
            !explicitTitle.isNullOrBlank() -> explicitTitle.trim()
            !streamTitle.isNullOrBlank() -> streamTitle
            !url.isNullOrBlank() -> deriveTitleFromUrl(url)
            else -> ""
        }

        return MediaMetadataInfo(
            title = finalTitle,
            artist = streamArtist,
            artworkBytes = artworkBytes
        )
    }

    /**
     * Derives a clean, human-readable title from a video URL.
     * Example: "https://.../sample/BigBuckBunny_1080p.mp4" -> "Big Buck Bunny"
     */
    fun deriveTitleFromUrl(url: String): String {
        if (url.isBlank()) return ""

        return try {
            val uri = Uri.parse(url)
            val path = uri.path ?: ""
            if (path.isBlank()) return ""

            // 1. Get last path segment (filename)
            var filename = path.substringAfterLast('/')
            if (filename.isBlank()) return ""

            // 2. Decode URL encoding (e.g. %20 -> space)
            try {
                filename = URLDecoder.decode(filename, StandardCharsets.UTF_8.name())
            } catch (_: Exception) {}

            // 3. Strip file extension
            val extensions = listOf(
                ".mp4", ".m4v", ".mov", ".mkv", ".webm",
                ".m3u8", ".mpd", ".ts", ".flv", ".3gp", ".avi", ".wmv"
            )
            for (ext in extensions) {
                if (filename.endsWith(ext, ignoreCase = true)) {
                    filename = filename.substring(0, filename.length - ext.length)
                    break
                }
            }

            // 4. Strip common technical tags
            val tagRegex = Regex("(?i)[\\[(_-]*(1080p|720p|480p|2160p|4k|h264|h265|hevc|aac|x264|x265|bluray|webrip)[\\])_-]*")
            filename = filename.replace(tagRegex, " ")

            // 5. Expand CamelCase to spaced words: "BigBuckBunny" -> "Big Buck Bunny"
            filename = filename.replace(Regex("(?<=[a-z])(?=[A-Z])"), " ")

            // 6. Replace delimiters (_, -, .) with spaces
            filename = filename.replace(Regex("[_\\-.]+"), " ").trim()

            // 7. Capitalize each word
            filename.split(Regex("\\s+"))
                .filter { it.isNotBlank() }
                .joinToString(" ") { word ->
                    word.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString() }
                }
        } catch (_: Exception) {
            ""
        }
    }
}
