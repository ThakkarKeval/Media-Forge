@file:Suppress("UNCHECKED_CAST")

package com.cavernlabs.media.forge.media_forge

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume

class MediaForgePicker(
    private val context: Context,
) : MediaForgePickerApi, PluginRegistry.ActivityResultListener {

    var activity: Activity? = null

    private var activeRequestCode: Int = 0
    private var pendingContinuation: Continuation<Any?>? = null
    private var pendingCameraFile: File? = null

    // Storage for unconsumed results recovered after Activity recreation
    private val lostDataItems = mutableListOf<NativePickedMedia>()
    private var lostDataError: Pair<String, String?>? = null

    companion object {
        private const val REQUEST_PICK_IMAGE = 4101
        private const val REQUEST_PICK_VIDEO = 4102
        private const val REQUEST_PICK_MULTIPLE = 4103
        private const val REQUEST_CAPTURE_IMAGE = 4104
        private const val REQUEST_CAPTURE_VIDEO = 4105
    }

    override suspend fun pickImage(
        source: NativeMediaSource,
        options: NativePickerOptions?,
    ): NativePickedMedia? {
        val currentActivity = activity ?: throw FlutterError(
            "no_activity",
            "MediaForge requires a foreground Activity to launch media selection",
            null,
        )

        return if (source == NativeMediaSource.CAMERA) {
            captureImage(currentActivity, options)
        } else {
            selectSingleMedia(currentActivity, REQUEST_PICK_IMAGE, "image/*", NativeMediaType.IMAGE)
        }
    }

    override suspend fun pickVideo(
        source: NativeMediaSource,
        options: NativePickerOptions?,
    ): NativePickedMedia? {
        val currentActivity = activity ?: throw FlutterError(
            "no_activity",
            "MediaForge requires a foreground Activity to launch media selection",
            null,
        )

        return if (source == NativeMediaSource.CAMERA) {
            captureVideo(currentActivity, options)
        } else {
            selectSingleMedia(currentActivity, REQUEST_PICK_VIDEO, "video/*", NativeMediaType.VIDEO)
        }
    }

    override suspend fun pickMultiple(
        type: NativeMediaType,
        options: NativePickerOptions?,
    ): List<NativePickedMedia> {
        val currentActivity = activity ?: throw FlutterError(
            "no_activity",
            "MediaForge requires a foreground Activity to launch media selection",
            null,
        )

        return suspendCancellableCoroutine { continuation ->
            val intent = createMultiplePickIntent(type, options?.maxItems)
            activeRequestCode = REQUEST_PICK_MULTIPLE
            pendingContinuation = continuation as Continuation<Any?>
            currentActivity.startActivityForResult(intent, REQUEST_PICK_MULTIPLE)
        }
    }

    override suspend fun retrieveLostData(): NativeLostDataResponse {
        val items = lostDataItems.toList()
        val error = lostDataError
        lostDataItems.clear()
        lostDataError = null

        return NativeLostDataResponse(
            items = items,
            errorCode = error?.first,
            errorMessage = error?.second,
        )
    }

    private suspend fun captureImage(
        activity: Activity,
        options: NativePickerOptions?,
    ): NativePickedMedia? {
        val tempFile = createCacheFile("IMG_", ".jpg")
        val contentUri = getFileProviderUri(tempFile)

        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, contentUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            if (options?.cameraDevice == NativeCameraDevice.FRONT) {
                putExtra("android.intent.extras.CAMERA_FACING", 1)
                putExtra("android.intent.extra.USE_FRONT_CAMERA", true)
            }
        }

        return suspendCancellableCoroutine { continuation ->
            activeRequestCode = REQUEST_CAPTURE_IMAGE
            pendingCameraFile = tempFile
            pendingContinuation = continuation as Continuation<Any?>
            activity.startActivityForResult(intent, REQUEST_CAPTURE_IMAGE)
        }
    }

    private suspend fun captureVideo(
        activity: Activity,
        options: NativePickerOptions?,
    ): NativePickedMedia? {
        val tempFile = createCacheFile("VID_", ".mp4")
        val contentUri = getFileProviderUri(tempFile)

        val intent = Intent(MediaStore.ACTION_VIDEO_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, contentUri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            options?.maxDurationSeconds?.let { maxSec ->
                putExtra(MediaStore.EXTRA_DURATION_LIMIT, maxSec.toInt())
            }
            if (options?.cameraDevice == NativeCameraDevice.FRONT) {
                putExtra("android.intent.extras.CAMERA_FACING", 1)
                putExtra("android.intent.extra.USE_FRONT_CAMERA", true)
            }
        }

        return suspendCancellableCoroutine { continuation ->
            activeRequestCode = REQUEST_CAPTURE_VIDEO
            pendingCameraFile = tempFile
            pendingContinuation = continuation as Continuation<Any?>
            activity.startActivityForResult(intent, REQUEST_CAPTURE_VIDEO)
        }
    }

    private suspend fun selectSingleMedia(
        activity: Activity,
        requestCode: Int,
        mimeType: String,
        targetType: NativeMediaType,
    ): NativePickedMedia? {
        return suspendCancellableCoroutine { continuation ->
            val intent = createSinglePickIntent(mimeType)
            activeRequestCode = requestCode
            pendingContinuation = continuation as Continuation<Any?>
            activity.startActivityForResult(intent, requestCode)
        }
    }

    private fun createSinglePickIntent(mimeType: String): Intent {
        // Modern PhotoPicker on API 33+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val intent = Intent(MediaStore.ACTION_PICK_IMAGES)
            if (mimeType.startsWith("image/")) {
                intent.type = "image/*"
            } else if (mimeType.startsWith("video/")) {
                intent.type = "video/*"
            }
            return intent
        }
        // Universal fallback for API 24 - 32
        return Intent(Intent.ACTION_GET_CONTENT).apply {
            type = mimeType
            addCategory(Intent.CATEGORY_OPENABLE)
        }
    }

    private fun createMultiplePickIntent(type: NativeMediaType, maxItems: Long?): Intent {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val intent = Intent(MediaStore.ACTION_PICK_IMAGES)
            maxItems?.let {
                if (it > 1) {
                    intent.putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, it.toInt())
                }
            }
            when (type) {
                NativeMediaType.IMAGE -> intent.type = "image/*"
                NativeMediaType.VIDEO -> intent.type = "video/*"
                NativeMediaType.MIXED -> { /* no type filter permits mixed visual media */ }
            }
            return intent
        }

        return Intent(Intent.ACTION_GET_CONTENT).apply {
            when (type) {
                NativeMediaType.IMAGE -> this.type = "image/*"
                NativeMediaType.VIDEO -> this.type = "video/*"
                NativeMediaType.MIXED -> {
                    this.type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
                }
            }
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != activeRequestCode && requestCode !in listOf(
                REQUEST_PICK_IMAGE, REQUEST_PICK_VIDEO, REQUEST_PICK_MULTIPLE,
                REQUEST_CAPTURE_IMAGE, REQUEST_CAPTURE_VIDEO
            )
        ) {
            return false
        }

        val continuation = pendingContinuation
        pendingContinuation = null
        activeRequestCode = 0

        val cameraFile = pendingCameraFile
        pendingCameraFile = null

        if (resultCode != Activity.RESULT_OK) {
            // User cancelled: clean up placeholder file if camera capture was cancelled
            cameraFile?.let { if (it.exists()) it.delete() }
            if (continuation != null) {
                if (requestCode == REQUEST_PICK_MULTIPLE) {
                    continuation.resume(emptyList<NativePickedMedia>())
                } else {
                    continuation.resume(null)
                }
            }
            return true
        }

        // Process successful result in background thread
        CoroutineScope(Dispatchers.IO).launch {
            try {
                when (requestCode) {
                    REQUEST_CAPTURE_IMAGE -> {
                        val result = if (cameraFile != null && cameraFile.exists() && cameraFile.length() > 0) {
                            inspectImageFile(cameraFile)
                        } else null
                        dispatchResult(continuation, result)
                    }
                    REQUEST_CAPTURE_VIDEO -> {
                        val result = if (cameraFile != null && cameraFile.exists() && cameraFile.length() > 0) {
                            inspectVideoFile(cameraFile)
                        } else null
                        dispatchResult(continuation, result)
                    }
                    REQUEST_PICK_IMAGE, REQUEST_PICK_VIDEO -> {
                        val uri = data?.data
                        val result = uri?.let { copyAndInspect(it) }
                        dispatchResult(continuation, result)
                    }
                    REQUEST_PICK_MULTIPLE -> {
                        val results = mutableListOf<NativePickedMedia>()
                        val clipData = data?.clipData
                        if (clipData != null) {
                            for (i in 0 until clipData.itemCount) {
                                val uri = clipData.getItemAt(i).uri
                                copyAndInspect(uri)?.let { results.add(it) }
                            }
                        } else {
                            data?.data?.let { uri ->
                                copyAndInspect(uri)?.let { results.add(it) }
                            }
                        }
                        dispatchResult(continuation, results)
                    }
                }
            } catch (e: Exception) {
                if (continuation != null) {
                    continuation.resumeWith(Result.failure(e))
                } else {
                    lostDataError = Pair("processing_error", e.message)
                }
            }
        }

        return true
    }

    private fun <T> dispatchResult(continuation: Continuation<Any?>?, result: T) {
        if (continuation != null) {
            continuation.resume(result)
        } else {
            // Activity recreation recovery: store unconsumed results
            if (result is NativePickedMedia) {
                lostDataItems.add(result)
            } else if (result is List<*>) {
                @Suppress("UNCHECKED_CAST")
                lostDataItems.addAll(result as List<NativePickedMedia>)
            }
        }
    }

    private suspend fun copyAndInspect(uri: Uri): NativePickedMedia? = withContext(Dispatchers.IO) {
        val mimeType = context.contentResolver.getType(uri) ?: getMimeTypeFromUri(uri)
        val isVideo = mimeType?.startsWith("video/") == true
        val ext = getExtensionForMime(mimeType) ?: if (isVideo) ".mp4" else ".jpg"
        val prefix = if (isVideo) "VID_" else "IMG_"
        val destFile = createCacheFile(prefix, ext)

        context.contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(destFile).use { output ->
                input.copyTo(output)
            }
        } ?: return@withContext null

        if (isVideo) {
            inspectVideoFile(destFile, mimeType)
        } else {
            inspectImageFile(destFile, mimeType)
        }
    }

    private fun inspectImageFile(file: File, explicitMime: String? = null): NativePickedMedia {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, options)

        val mime = explicitMime ?: options.outMimeType ?: "image/jpeg"
        val width = if (options.outWidth > 0) options.outWidth.toLong() else null
        val height = if (options.outHeight > 0) options.outHeight.toLong() else null

        return NativePickedMedia(
            path = file.absolutePath,
            type = NativeMediaType.IMAGE,
            name = file.name,
            mimeType = mime,
            sizeBytes = file.length(),
            width = width,
            height = height,
            durationMs = null,
        )
    }

    private fun inspectVideoFile(file: File, explicitMime: String? = null): NativePickedMedia {
        val retriever = MediaMetadataRetriever()
        var width: Long? = null
        var height: Long? = null
        var durationMs: Long? = null

        try {
            retriever.setDataSource(file.absolutePath)
            val durationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            durationMs = durationStr?.toLongOrNull()

            val widthStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val heightStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val rotationStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)

            val rawWidth = widthStr?.toLongOrNull()
            val rawHeight = heightStr?.toLongOrNull()
            val rotation = rotationStr?.toIntOrNull() ?: 0

            if (rotation == 90 || rotation == 270) {
                width = rawHeight
                height = rawWidth
            } else {
                width = rawWidth
                height = rawHeight
            }
        } catch (_: Exception) {
            // Best effort extraction
        } finally {
            retriever.release()
        }

        return NativePickedMedia(
            path = file.absolutePath,
            type = NativeMediaType.VIDEO,
            name = file.name,
            mimeType = explicitMime ?: "video/mp4",
            sizeBytes = file.length(),
            width = width,
            height = height,
            durationMs = durationMs,
        )
    }

    private fun createCacheFile(prefix: String, suffix: String): File {
        val dir = File(context.cacheDir, "media_forge").apply {
            if (!exists()) mkdirs()
        }
        return File.createTempFile(prefix, suffix, dir)
    }

    private fun getFileProviderUri(file: File): Uri {
        val authority = "${context.packageName}.media_forge.fileprovider"
        return FileProvider.getUriForFile(context, authority, file)
    }

    private fun getMimeTypeFromUri(uri: Uri): String? {
        val ext = MimeTypeMap.getFileExtensionFromUrl(uri.toString()) ?: return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.lowercase())
    }

    private fun getExtensionForMime(mimeType: String?): String? {
        if (mimeType == null) return null
        val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
        return if (ext != null) ".$ext" else null
    }
}
