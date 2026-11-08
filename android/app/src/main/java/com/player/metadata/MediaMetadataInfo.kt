package com.player.metadata

import java.util.Arrays

/**
 * Immutable data model representing resolved media metadata.
 */
data class MediaMetadataInfo(
    val title: String,
    val artist: String? = null,
    val artworkBytes: ByteArray? = null
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as MediaMetadataInfo

        if (title != other.title) return false
        if (artist != other.artist) return false
        if (artworkBytes != null) {
            if (other.artworkBytes == null) return false
            if (!artworkBytes.contentEquals(other.artworkBytes)) return false
        } else if (other.artworkBytes != null) return false

        return true
    }

    override fun hashCode(): Int {
        var result = title.hashCode()
        result = 31 * result + (artist?.hashCode() ?: 0)
        result = 31 * result + (artworkBytes?.contentHashCode() ?: 0)
        return result
    }
}
