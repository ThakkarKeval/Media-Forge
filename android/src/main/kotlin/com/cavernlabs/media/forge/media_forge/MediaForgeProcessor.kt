package com.cavernlabs.media.forge.media_forge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.media.ExifInterface
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class MediaForgeProcessor(
    private val context: Context,
) : MediaForgeProcessorApi {

    override suspend fun processImage(
        path: String,
        options: NativeImageProcessOptions,
    ): NativeProcessedMedia = withContext(Dispatchers.IO) {
        val sourceFile = File(path)
        if (!sourceFile.exists()) {
            throw FlutterError("file_not_found", "Source image file does not exist: $path", null)
        }

        val originalSizeBytes = sourceFile.length()

        // 1. Inspect original bounds and MIME
        val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(sourceFile.absolutePath, boundsOptions)
        val originalWidth = boundsOptions.outWidth
        val originalHeight = boundsOptions.outHeight
        val originalMime = boundsOptions.outMimeType ?: "image/jpeg"

        if (originalWidth <= 0 || originalHeight <= 0) {
            throw FlutterError("invalid_image", "Failed to decode image dimensions from: $path", null)
        }

        // 2. Determine target format
        val targetFormatName = options.format?.lowercase() ?: getFormatFromMime(originalMime)
        val compressFormat = getCompressFormat(targetFormatName)
        val targetMime = getMimeForFormat(targetFormatName)
        val targetExt = getExtensionForFormat(targetFormatName)

        // 3. Read EXIF orientation
        val exif = try {
            ExifInterface(sourceFile.absolutePath)
        } catch (_: IOException) {
            null
        }
        val orientation = exif?.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL
        ) ?: ExifInterface.ORIENTATION_NORMAL

        val isRotated90 = orientation == ExifInterface.ORIENTATION_ROTATE_90 ||
                orientation == ExifInterface.ORIENTATION_ROTATE_270 ||
                orientation == ExifInterface.ORIENTATION_TRANSVERSE ||
                orientation == ExifInterface.ORIENTATION_TRANSPOSE

        val orientedWidth = if (isRotated90) originalHeight else originalWidth
        val orientedHeight = if (isRotated90) originalWidth else originalHeight

        // 4. Calculate target dimensions (preserves aspect ratio, no upscaling by default)
        val (finalWidth, finalHeight) = calculateTargetDimensions(
            orientedWidth,
            orientedHeight,
            options.maxWidth?.toInt(),
            options.maxHeight?.toInt(),
        )

        // 5. Decode bitmap with inSampleSize
        val decodeOptions = BitmapFactory.Options().apply {
            inSampleSize = calculateInSampleSize(originalWidth, originalHeight, finalWidth, finalHeight)
        }
        var decodedBitmap = BitmapFactory.decodeFile(sourceFile.absolutePath, decodeOptions)
            ?: throw FlutterError("decode_failed", "Failed to decode image: $path", null)

        // 6. Apply EXIF orientation transform
        val matrix = getOrientationMatrix(orientation)
        if (!matrix.isIdentity) {
            val rotatedBitmap = Bitmap.createBitmap(
                decodedBitmap, 0, 0,
                decodedBitmap.width, decodedBitmap.height,
                matrix, true
            )
            if (rotatedBitmap != decodedBitmap) {
                decodedBitmap.recycle()
                decodedBitmap = rotatedBitmap
            }
        }

        // 7. Scale to exact target dimensions if needed
        if (decodedBitmap.width != finalWidth || decodedBitmap.height != finalHeight) {
            val scaledBitmap = Bitmap.createScaledBitmap(decodedBitmap, finalWidth, finalHeight, true)
            if (scaledBitmap != decodedBitmap) {
                decodedBitmap.recycle()
                decodedBitmap = scaledBitmap
            }
        }

        // 8. Handle transparency for JPEG conversion
        if (compressFormat == Bitmap.CompressFormat.JPEG && decodedBitmap.hasAlpha()) {
            val opaqueBitmap = Bitmap.createBitmap(decodedBitmap.width, decodedBitmap.height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(opaqueBitmap)
            canvas.drawColor(Color.WHITE)
            canvas.drawBitmap(decodedBitmap, 0f, 0f, Paint())
            decodedBitmap.recycle()
            decodedBitmap = opaqueBitmap
        }

        // 9. Compress with best-effort target size or quality
        val initialQuality = (options.quality ?: 85L).toInt().coerceIn(1, 100)
        val targetBytes = options.targetSizeBytes

        val (compressedBytes, targetMet) = if (targetBytes != null && compressFormat != Bitmap.CompressFormat.PNG) {
            findBestEffortQuality(decodedBitmap, compressFormat, targetBytes, initialQuality)
        } else {
            val stream = ByteArrayOutputStream()
            decodedBitmap.compress(compressFormat, initialQuality, stream)
            Pair(stream.toByteArray(), null)
        }

        decodedBitmap.recycle()

        // 10. Write output file
        val destFile = createCacheFile("PROC_", targetExt)
        FileOutputStream(destFile).use { fos ->
            fos.write(compressedBytes)
        }

        // 11. Copy EXIF metadata (excluding GPS if stripGpsMetadata == true)
        val stripGps = options.stripGpsMetadata ?: true
        copyExifAttributes(sourceFile, destFile, stripGps)

        val outputSizeBytes = destFile.length()

        return@withContext NativeProcessedMedia(
            path = destFile.absolutePath,
            originalPath = sourceFile.absolutePath,
            mimeType = targetMime,
            sizeBytes = outputSizeBytes,
            originalSizeBytes = originalSizeBytes,
            width = finalWidth.toLong(),
            height = finalHeight.toLong(),
            changed = true,
            targetMet = targetMet,
        )
    }

    override suspend fun inspectVideo(path: String): NativeVideoMetadata = withContext(Dispatchers.IO) {
        throw FlutterError("unimplemented", "inspectVideo is part of Milestone 3", null)
    }

    override suspend fun createVideoThumbnail(
        videoPath: String,
        atMs: Long,
        maxWidth: Long?,
        maxHeight: Long?,
    ): String = withContext(Dispatchers.IO) {
        throw FlutterError("unimplemented", "createVideoThumbnail is part of Milestone 3", null)
    }

    override suspend fun clearCache(): Boolean = withContext(Dispatchers.IO) {
        val dir = File(context.cacheDir, "media_forge")
        if (dir.exists() && dir.isDirectory) {
            dir.listFiles()?.forEach { file ->
                if (file.isFile) file.delete()
            }
        }
        return@withContext true
    }

    // --- Helper Calculations ---

    private fun calculateTargetDimensions(
        srcWidth: Int,
        srcHeight: Int,
        maxWidth: Int?,
        maxHeight: Int?,
    ): Pair<Int, Int> {
        var targetW = srcWidth
        var targetH = srcHeight

        if (maxWidth == null && maxHeight == null) {
            return Pair(targetW, targetH)
        }

        val widthRatio = maxWidth?.let { it.toFloat() / srcWidth.toFloat() } ?: Float.MAX_VALUE
        val heightRatio = maxHeight?.let { it.toFloat() / srcHeight.toFloat() } ?: Float.MAX_VALUE
        val scale = min(widthRatio, heightRatio)

        if (scale < 1.0f) {
            targetW = max(1, (srcWidth * scale).roundToInt())
            targetH = max(1, (srcHeight * scale).roundToInt())
        }

        return Pair(targetW, targetH)
    }

    private fun calculateInSampleSize(srcWidth: Int, srcHeight: Int, reqWidth: Int, reqHeight: Int): Int {
        var inSampleSize = 1
        if (srcHeight > reqHeight || srcWidth > reqWidth) {
            val halfHeight = srcHeight / 2
            val halfWidth = srcWidth / 2
            while ((halfHeight / inSampleSize) >= reqHeight && (halfWidth / inSampleSize) >= reqWidth) {
                inSampleSize *= 2
            }
        }
        return inSampleSize
    }

    private fun getOrientationMatrix(orientation: Int): Matrix {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.postScale(-1f, 1f)
            }
        }
        return matrix
    }

    private fun findBestEffortQuality(
        bitmap: Bitmap,
        format: Bitmap.CompressFormat,
        targetBytes: Long,
        maxQuality: Int,
    ): Pair<ByteArray, Boolean> {
        var low = 10
        var high = maxQuality
        var bestBytes: ByteArray? = null
        var bestQuality = maxQuality

        for (i in 0 until 5) {
            val mid = (low + high) / 2
            val stream = ByteArrayOutputStream()
            bitmap.compress(format, mid, stream)
            val currentBytes = stream.toByteArray()

            if (currentBytes.size <= targetBytes) {
                bestBytes = currentBytes
                bestQuality = mid
                low = mid + 1 // try higher quality while staying under target
            } else {
                high = mid - 1
                if (bestBytes == null || currentBytes.size < bestBytes.size) {
                    bestBytes = currentBytes
                }
            }
            if (low > high) break
        }

        val finalBytes = bestBytes ?: run {
            val stream = ByteArrayOutputStream()
            bitmap.compress(format, low.coerceIn(10, maxQuality), stream)
            stream.toByteArray()
        }

        val targetMet = finalBytes.size <= targetBytes
        return Pair(finalBytes, targetMet)
    }

    private fun copyExifAttributes(sourceFile: File, destFile: File, stripGps: Boolean) {
        try {
            val srcExif = ExifInterface(sourceFile.absolutePath)
            val destExif = ExifInterface(destFile.absolutePath)

            val tags = arrayOf(
                ExifInterface.TAG_DATETIME,
                ExifInterface.TAG_FLASH,
                ExifInterface.TAG_FOCAL_LENGTH,
                ExifInterface.TAG_IMAGE_LENGTH,
                ExifInterface.TAG_IMAGE_WIDTH,
                ExifInterface.TAG_MAKE,
                ExifInterface.TAG_MODEL,
                ExifInterface.TAG_WHITE_BALANCE,
                ExifInterface.TAG_EXPOSURE_TIME,
                ExifInterface.TAG_F_NUMBER,
                ExifInterface.TAG_ISO_SPEED_RATINGS,
            )

            for (tag in tags) {
                val value = srcExif.getAttribute(tag)
                if (value != null) {
                    destExif.setAttribute(tag, value)
                }
            }

            if (!stripGps) {
                val gpsTags = arrayOf(
                    ExifInterface.TAG_GPS_LATITUDE,
                    ExifInterface.TAG_GPS_LATITUDE_REF,
                    ExifInterface.TAG_GPS_LONGITUDE,
                    ExifInterface.TAG_GPS_LONGITUDE_REF,
                    ExifInterface.TAG_GPS_ALTITUDE,
                    ExifInterface.TAG_GPS_ALTITUDE_REF,
                    ExifInterface.TAG_GPS_TIMESTAMP,
                    ExifInterface.TAG_GPS_DATESTAMP,
                    ExifInterface.TAG_GPS_PROCESSING_METHOD,
                )
                for (tag in gpsTags) {
                    val value = srcExif.getAttribute(tag)
                    if (value != null) {
                        destExif.setAttribute(tag, value)
                    }
                }
            }

            destExif.saveAttributes()
        } catch (_: Exception) {
            // Non-critical EXIF preservation
        }
    }

    private fun getFormatFromMime(mime: String): String {
        return when {
            mime.contains("png") -> "png"
            mime.contains("webp") -> "webp"
            else -> "jpeg"
        }
    }

    private fun getCompressFormat(format: String): Bitmap.CompressFormat {
        return when (format) {
            "png" -> Bitmap.CompressFormat.PNG
            "webp" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    Bitmap.CompressFormat.WEBP_LOSSY
                } else {
                    @Suppress("DEPRECATION")
                    Bitmap.CompressFormat.WEBP
                }
            }
            else -> Bitmap.CompressFormat.JPEG
        }
    }

    private fun getMimeForFormat(format: String): String {
        return when (format) {
            "png" -> "image/png"
            "webp" -> "image/webp"
            else -> "image/jpeg"
        }
    }

    private fun getExtensionForFormat(format: String): String {
        return when (format) {
            "png" -> ".png"
            "webp" -> ".webp"
            else -> ".jpg"
        }
    }

    private fun createCacheFile(prefix: String, suffix: String): File {
        val dir = File(context.cacheDir, "media_forge").apply {
            if (!exists()) mkdirs()
        }
        return File.createTempFile(prefix, suffix, dir)
    }
}
