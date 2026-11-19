import 'dart:io';

import '../errors/error_codes.dart';
import '../errors/media_forge_exception.dart';
import '../models/image_options.dart';
import '../models/processed_media.dart';
import '../platform/media_forge_platform.dart';

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

  /// Clears managed temporary intermediate output files created by the processor.
  static Future<bool> clearCache() {
    return _platform.clearCache();
  }
}
