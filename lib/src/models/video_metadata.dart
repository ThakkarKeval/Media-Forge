import 'dart:io';

/// Inspected metadata for a local video file.
/// Note: MediaForge v0.1 only inspects video and extracts thumbnails;
/// it does not perform video transcoding or compression.
class VideoMetadata {
  /// Constructs a [VideoMetadata] descriptor.
  const VideoMetadata({
    required this.path,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.duration,
    this.rotationDegrees = 0,
  });

  /// The accessible local filesystem path to the video.
  final String path;

  /// The inspected MIME type (e.g. `video/mp4`, `video/quicktime`).
  final String? mimeType;

  /// The file size in bytes.
  final int? sizeBytes;

  /// Oriented pixel width of the video.
  final int? width;

  /// Oriented pixel height of the video.
  final int? height;

  /// Total duration of the video.
  final Duration? duration;

  /// Video track orientation rotation in degrees (e.g. 0, 90, 180, 270).
  final int rotationDegrees;

  /// Convenience getter returning a [File] handle pointing to [path].
  File get file => File(path);

  /// Aspect ratio (`width / height`) if dimensions are available.
  double? get aspectRatio {
    if (width == null || height == null || height! <= 0) return null;
    return width! / height!;
  }

  @override
  String toString() =>
      'VideoMetadata(path: $path, ${width}x$height, duration: ${duration?.inSeconds}s, size: $sizeBytes, rot: $rotationDegrees°)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoMetadata &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          sizeBytes == other.sizeBytes &&
          duration == other.duration;

  @override
  int get hashCode => path.hashCode ^ (sizeBytes?.hashCode ?? 0) ^ (duration?.hashCode ?? 0);
}
