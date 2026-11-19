import 'dart:io';

/// The result of an image optimization or conversion operation.
class ProcessedMedia {
  /// Constructs a [ProcessedMedia] descriptor.
  const ProcessedMedia({
    required this.path,
    required this.originalPath,
    this.mimeType,
    this.sizeBytes,
    this.originalSizeBytes,
    this.width,
    this.height,
    required this.changed,
    this.targetMet,
  });

  /// The accessible local filesystem path to the optimized/converted file.
  final String path;

  /// The filesystem path to the original source input file.
  final String originalPath;

  /// The inspected or encoded MIME type (e.g. `image/jpeg`, `image/webp`).
  final String? mimeType;

  /// The output file size in bytes.
  final int? sizeBytes;

  /// The original source file size in bytes before processing.
  final int? originalSizeBytes;

  /// Pixel width of the processed image.
  final int? width;

  /// Pixel height of the processed image.
  final int? height;

  /// Whether transformations (resizing, recompression, or format conversion)
  /// were applied. `false` indicates smart passthrough where the original was reused.
  final bool changed;

  /// Whether the requested [targetSizeBytes] constraint was met.
  /// `null` if no target size was requested.
  final bool? targetMet;

  /// Convenience getter returning a [File] handle pointing to [path].
  File get file => File(path);

  /// Difference in bytes saved (positive if smaller, negative if larger).
  int? get savingsBytes {
    if (sizeBytes == null || originalSizeBytes == null) return null;
    return originalSizeBytes! - sizeBytes!;
  }

  /// Percentage size reduction (e.g. 45.0 for 45% reduction).
  double? get savingsPercentage {
    if (savingsBytes == null ||
        originalSizeBytes == null ||
        originalSizeBytes! <= 0) {
      return null;
    }
    return (savingsBytes! / originalSizeBytes!) * 100.0;
  }

  @override
  String toString() =>
      'ProcessedMedia(path: $path, size: $sizeBytes, ${width}x$height, changed: $changed, targetMet: $targetMet)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessedMedia &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          originalPath == other.originalPath &&
          sizeBytes == other.sizeBytes &&
          changed == other.changed &&
          targetMet == other.targetMet;

  @override
  int get hashCode =>
      path.hashCode ^
      originalPath.hashCode ^
      (sizeBytes?.hashCode ?? 0) ^
      changed.hashCode ^
      (targetMet?.hashCode ?? 0);
}
