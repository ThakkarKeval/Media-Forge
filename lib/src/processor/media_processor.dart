import 'dart:io';

import '../errors/error_codes.dart';
import '../errors/media_forge_exception.dart';
import '../models/batch_result.dart';
import '../models/image_options.dart';
import '../models/processed_media.dart';
import '../models/video_metadata.dart';
import '../platform/media_forge_platform.dart';
import 'batch_job.dart';

/// Entrypoint for image processing, optimization, and media inspection.
class MediaProcessor {
  const MediaProcessor._();

  static MediaForgePlatform get _platform => MediaForgePlatform.instance;

  /// Processes and optimizes a local image file located at [path].
  ///
  /// Supports resizing, quality compression, format conversion, EXIF orientation
  /// normalization, and stripping GPS metadata as configured in [options].
  ///
  /// The original file at [path] is never overwritten; output is written to a
  /// newly created unique file in managed application temporary storage.
  ///
  /// Throws [MediaForgeException] if the input file does not exist, format is
  /// unsupported, or native processing encounters an error.
  static Future<ProcessedMedia> processImage(
    String path, {
    ImageProcessingOptions options = const ImageProcessingOptions(),
  }) async {
    if (path.trim().isEmpty) {
      throw const MediaForgeException(
        code: MediaForgeErrorCode.fileNotFound,
        message: 'Image path must not be empty',
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      throw MediaForgeException(
        code: MediaForgeErrorCode.fileNotFound,
        message: 'Source image file does not exist at path: $path',
      );
    }

    return _platform.processImage(path: path, options: options);
  }

  /// Processes multiple image files located at [paths] using a bounded concurrency pool.
  ///
  /// Concurrency is bounded to [concurrency] (default 2) to protect device memory.
  /// Returns a [BatchJob] which provides a broadcast stream of [ProcessingEvent]s,
  /// a cancellation method, and a future completing with an ordered [BatchResult].
  static BatchJob processImages(
    List<String> paths, {
    ImageProcessingOptions options = const ImageProcessingOptions(),
    int concurrency = 2,
  }) {
    return BatchJob.start(
      paths: paths,
      options: options,
      concurrency: concurrency,
    );
  }

  /// Inspects metadata for a local video file located at [path].
  ///
  /// MediaForge v0.1 provides inspection (duration, dimensions, file size,
  /// rotation, MIME type) and thumbnail generation only; it does not perform
  /// video transcoding or compression.
  ///
  /// Throws [MediaForgeException] if the file does not exist or inspection fails.
  static Future<VideoMetadata> inspectVideo(String path) async {
    if (path.trim().isEmpty) {
      throw const MediaForgeException(
        code: MediaForgeErrorCode.fileNotFound,
        message: 'Video path must not be empty',
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      throw MediaForgeException(
        code: MediaForgeErrorCode.fileNotFound,
        message: 'Source video file does not exist at path: $path',
      );
    }

    return _platform.inspectVideo(path);
  }

  /// Extracts a video frame thumbnail at [atTime] (default start of video).
  ///
  /// Returns the local filesystem path to the newly created thumbnail image.
  /// Optional [maxWidth] and [maxHeight] constrain the generated thumbnail dimensions.
  ///
  /// Throws [MediaForgeException] if extraction fails.
  static Future<String> createVideoThumbnail({
    required String videoPath,
    Duration atTime = Duration.zero,
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (videoPath.trim().isEmpty) {
      throw const MediaForgeException(
        code: MediaForgeErrorCode.fileNotFound,
        message: 'Video path must not be empty',
      );
    }

    final file = File(videoPath);
    if (!await file.exists()) {
      throw MediaForgeException(
        code: MediaForgeErrorCode.fileNotFound,
        message: 'Source video file does not exist at path: $videoPath',
      );
    }

    return _platform.createVideoThumbnail(
      videoPath: videoPath,
      atTime: atTime,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  /// Clears managed temporary intermediate output files created by the processor.
  static Future<bool> clearCache() {
    return _platform.clearCache();
  }
}
