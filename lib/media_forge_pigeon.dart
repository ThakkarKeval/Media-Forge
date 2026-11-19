import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_forge_platform_interface.dart';
import 'src/errors/error_codes.dart';
import 'src/errors/media_forge_exception.dart';
import 'src/messages.g.dart';
import 'src/models/image_options.dart';
import 'src/models/lost_data_response.dart';
import 'src/models/media_source.dart';
import 'src/models/media_type.dart';
import 'src/models/picked_media.dart';
import 'src/models/processed_media.dart';
import 'src/models/selection_options.dart';
import 'src/models/video_metadata.dart';

/// An implementation of [MediaForgePlatform] that uses Pigeon for native platforms.
class PigeonMediaForge extends MediaForgePlatform {
  /// Creates a new plugin implementation instance with optional injected APIs for testing.
  PigeonMediaForge({
    @visibleForTesting MediaForgePluginApi? pluginApi,
    @visibleForTesting MediaForgePickerApi? pickerApi,
    @visibleForTesting MediaForgeProcessorApi? processorApi,
  }) : _pluginApi = pluginApi ?? MediaForgePluginApi(),
       _pickerApi = pickerApi ?? MediaForgePickerApi(),
       _processorApi = processorApi ?? MediaForgeProcessorApi();

  final MediaForgePluginApi _pluginApi;
  final MediaForgePickerApi _pickerApi;
  final MediaForgeProcessorApi _processorApi;

  @override
  Future<String?> getPlatformVersion() async {
    try {
      return await _pluginApi.getPlatformVersion();
    } catch (e) {
      throw _wrapException(e);
    }
  }

  @override
  Future<PickedMedia?> pickImage({
    required MediaSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    MediaSelectionOptions? options,
  }) async {
    try {
      final nativeSource = _toNativeSource(source);
      final nativeOptions = _toNativeOptions(
        options,
        cameraDevice: preferredCameraDevice,
        maxItems: 1,
      );
      final result = await _pickerApi.pickImage(nativeSource, nativeOptions);
      if (result == null) return null;
      return _toPickedMedia(result);
    } catch (e) {
      throw _wrapException(e);
    }
  }

  @override
  Future<PickedMedia?> pickVideo({
    required MediaSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
    MediaSelectionOptions? options,
  }) async {
    try {
      final nativeSource = _toNativeSource(source);
      final nativeOptions = _toNativeOptions(
        options,
        cameraDevice: preferredCameraDevice,
        maxDuration: maxDuration,
        maxItems: 1,
      );
      final result = await _pickerApi.pickVideo(nativeSource, nativeOptions);
      if (result == null) return null;
      return _toPickedMedia(result);
    } catch (e) {
      throw _wrapException(e);
    }
  }

  @override
  Future<List<PickedMedia>> pickMultiple({
    required MediaType type,
    int? maxItems,
    MediaSelectionOptions? options,
  }) async {
    try {
      final nativeType = _toNativeType(type);
      final nativeOptions = _toNativeOptions(options, maxItems: maxItems);
      final results = await _pickerApi.pickMultiple(nativeType, nativeOptions);
      return results.map(_toPickedMedia).toList();
    } catch (e) {
      throw _wrapException(e);
    }
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    try {
      final nativeResponse = await _pickerApi.retrieveLostData();
      return _toLostDataResponse(nativeResponse);
    } catch (e) {
      throw _wrapException(e);
    }
  }

  @override
  Future<ProcessedMedia> processImage({
    required String path,
    required ImageProcessingOptions options,
  }) async {
    try {
      final nativeOptions = NativeImageProcessOptions(
        maxWidth: options.maxWidth,
        maxHeight: options.maxHeight,
        quality: options.quality,
        targetSizeBytes: options.targetSizeBytes,
        stripGpsMetadata: options.stripGpsMetadata,
        format: options.format?.name,
      );
      final nativeResult = await _processorApi.processImage(
        path,
        nativeOptions,
      );
      return _toProcessedMedia(nativeResult);
    } catch (e) {
      throw _wrapException(e);
    }
  }

  @override
  Future<bool> clearCache() async {
    try {
      return await _processorApi.clearCache();
    } catch (e) {
      throw _wrapException(e);
    }
  }

  @override
  Future<VideoMetadata> inspectVideo(String path) async {
    try {
      final nativeMeta = await _processorApi.inspectVideo(path);
      return _toVideoMetadata(nativeMeta);
    } catch (e) {
      throw _wrapException(e);
    }
  }

  @override
  Future<String> createVideoThumbnail({
    required String videoPath,
    Duration atTime = Duration.zero,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      return await _processorApi.createVideoThumbnail(
        videoPath,
        atTime.inMilliseconds,
        maxWidth,
        maxHeight,
      );
    } catch (e) {
      throw _wrapException(e);
    }
  }

  // --- Helpers ---

  NativeMediaSource _toNativeSource(MediaSource source) {
    switch (source) {
      case MediaSource.gallery:
        return NativeMediaSource.gallery;
      case MediaSource.camera:
        return NativeMediaSource.camera;
    }
  }

  NativeMediaType _toNativeType(MediaType type) {
    switch (type) {
      case MediaType.image:
        return NativeMediaType.image;
      case MediaType.video:
        return NativeMediaType.video;
      case MediaType.mixed:
        return NativeMediaType.mixed;
    }
  }

  NativeCameraDevice _toNativeCameraDevice(CameraDevice device) {
    switch (device) {
      case CameraDevice.rear:
        return NativeCameraDevice.rear;
      case CameraDevice.front:
        return NativeCameraDevice.front;
    }
  }

  NativePickerOptions _toNativeOptions(
    MediaSelectionOptions? options, {
    CameraDevice? cameraDevice,
    Duration? maxDuration,
    int? maxItems,
  }) {
    final effectiveMaxItems = maxItems ?? options?.maxItems;
    final effectiveCamera = cameraDevice ?? options?.preferredCameraDevice;
    final effectiveDuration = maxDuration ?? options?.maxDuration;

    return NativePickerOptions(
      maxItems: effectiveMaxItems,
      cameraDevice: effectiveCamera != null
          ? _toNativeCameraDevice(effectiveCamera)
          : null,
      maxDurationSeconds: effectiveDuration?.inSeconds,
    );
  }

  PickedMedia _toPickedMedia(NativePickedMedia native) {
    final mediaType = native.type == NativeMediaType.video
        ? MediaType.video
        : MediaType.image;

    Duration? duration;
    if (native.durationMs != null) {
      duration = Duration(milliseconds: native.durationMs!);
    }

    return PickedMedia(
      path: native.path,
      type: mediaType,
      name: native.name,
      mimeType: native.mimeType,
      sizeBytes: native.sizeBytes,
      width: native.width,
      height: native.height,
      duration: duration,
    );
  }

  ProcessedMedia _toProcessedMedia(NativeProcessedMedia native) {
    return ProcessedMedia(
      path: native.path,
      originalPath: native.originalPath,
      mimeType: native.mimeType,
      sizeBytes: native.sizeBytes,
      originalSizeBytes: native.originalSizeBytes,
      width: native.width,
      height: native.height,
      changed: native.changed,
      targetMet: native.targetMet,
    );
  }

  VideoMetadata _toVideoMetadata(NativeVideoMetadata native) {
    Duration? duration;
    if (native.durationMs != null) {
      duration = Duration(milliseconds: native.durationMs!);
    }

    return VideoMetadata(
      path: native.path,
      mimeType: native.mimeType,
      sizeBytes: native.sizeBytes,
      width: native.width,
      height: native.height,
      duration: duration,
      rotationDegrees: native.rotationDegrees ?? 0,
    );
  }

  LostDataResponse _toLostDataResponse(NativeLostDataResponse native) {
    final items = native.items.map(_toPickedMedia).toList();
    MediaForgeException? exception;
    if (native.errorCode != null) {
      exception = MediaForgeException(
        code: _mapErrorCode(native.errorCode!),
        message: native.errorMessage ?? 'An error occurred before recovery',
      );
    }
    return LostDataResponse(items: items, exception: exception);
  }

  MediaForgeErrorCode _mapErrorCode(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('permission')) {
      return MediaForgeErrorCode.permissionDenied;
    } else if (lower.contains('cancel')) {
      return MediaForgeErrorCode.cancelled;
    } else if (lower.contains('not_found') || lower.contains('notfound')) {
      return MediaForgeErrorCode.fileNotFound;
    } else if (lower.contains('unsupported')) {
      return MediaForgeErrorCode.unsupportedFormat;
    } else if (lower.contains('target_unreachable') ||
        lower.contains('targetunreachable')) {
      return MediaForgeErrorCode.targetUnreachable;
    } else if (lower.contains('processing')) {
      return MediaForgeErrorCode.processingFailed;
    }
    return MediaForgeErrorCode.platformFailure;
  }

  MediaForgeException _wrapException(Object error) {
    if (error is MediaForgeException) {
      return error;
    }
    if (error is PlatformException) {
      return MediaForgeException(
        code: _mapErrorCode(error.code),
        message: error.message ?? 'Platform error occurred: ${error.code}',
        details: error.details,
      );
    }
    return MediaForgeException(
      code: MediaForgeErrorCode.platformFailure,
      message: error.toString(),
    );
  }
}
