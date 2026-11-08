package com.player.thumbnail

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.LruCache
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Dedicated, thread-safe Thumbnail Provider for Android & Android TV.
 *
 * Provides:
 * 1. Embedded container artwork decoding (MP4 covr atom / ID3 APIC)
 * 2. Asynchronous 1.0s video frame capture via MediaMetadataRetriever
 * 3. High-performance in-memory LRU Bitmap cache (max 20MB)
 */
class ThumbnailProvider(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    // 20MB in-memory LRU cache
    private val memoryCache: LruCache<String, Bitmap> = object : LruCache<String, Bitmap>(20 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap): Int {
            return value.byteCount
        }
    }

    /**
     * Loads a thumbnail for the specified video URL or embedded artwork bytes.
     */
    fun loadThumbnail(
        videoUrl: String,
        artworkBytes: ByteArray?,
        headers: Map<String, String>?,
        onLoaded: (Bitmap?) -> Unit
    ) {
        if (videoUrl.isBlank() && artworkBytes == null) {
            onLoaded(null)
            return
        }

        val cacheKey = if (artworkBytes != null) "bytes_${artworkBytes.size}_${artworkBytes.hashCode()}" else videoUrl

        // 1. Check in-memory cache
        val cached = memoryCache.get(cacheKey)
        if (cached != null) {
            onLoaded(cached)
            return
        }

        // 2. Decode embedded artwork bytes if available
        if (artworkBytes != null && artworkBytes.isNotEmpty()) {
            executor.execute {
                try {
                    val bitmap = BitmapFactory.decodeByteArray(artworkBytes, 0, artworkBytes.size)
                    if (bitmap != null) {
                        memoryCache.put(cacheKey, bitmap)
                        mainHandler.post { onLoaded(bitmap) }
                    } else {
                        mainHandler.post { onLoaded(null) }
                    }
                } catch (_: Exception) {
                    mainHandler.post { onLoaded(null) }
                }
            }
            return
        }

        // 3. Fallback: Asynchronously extract frame at 1.0 second
        executor.execute {
            val retriever = MediaMetadataRetriever()
            try {
                if (videoUrl.startsWith("http://") || videoUrl.startsWith("https://")) {
                    retriever.setDataSource(videoUrl, headers ?: emptyMap())
                } else {
                    retriever.setDataSource(context, Uri.parse(videoUrl))
                }

                // 1,000,000 microseconds = 1.0 second
                val bitmap = retriever.getFrameAtTime(1_000_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                if (bitmap != null) {
                    memoryCache.put(cacheKey, bitmap)
                    mainHandler.post { onLoaded(bitmap) }
                } else {
                    mainHandler.post { onLoaded(null) }
                }
            } catch (_: Exception) {
                mainHandler.post { onLoaded(null) }
            } finally {
                try {
                    retriever.release()
                } catch (_: Exception) {}
            }
        }
    }

    fun release() {
        executor.shutdown()
        memoryCache.evictAll()
    }
}
