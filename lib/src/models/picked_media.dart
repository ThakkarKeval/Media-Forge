import 'dart:io';

import 'media_type.dart';

/// Represents a media item selected from the gallery or captured via camera.
class PickedMedia {
  /// Constructs a [PickedMedia] descriptor.
  const PickedMedia({
    required this.path,
    required this.type,
    this.name,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.duration,
  });

  /// The accessible local filesystem path to the media asset.
  final String path;

  /// The category of media (image or video).
  final MediaType type;

  /// The original filename or suggested name, if available.
  final String? name;

  /// The inspected or declared MIME type (e.g. `image/jpeg`, `video/mp4`).
  final String? mimeType;

  /// The file size in bytes, if known at pick time.
  final int? sizeBytes;

  /// Pixel width of the media item, if available.
  final int? width;

  /// Pixel height of the media item, if available.
  final int? height;

  /// Duration of video media, or null for images.
  final Duration? duration;

  /// Convenience getter returning a [File] handle pointing to [path].
  File get file => File(path);

  /// Convenience check whether this picked item is an image.
  bool get isImage => type == MediaType.image;

  /// Convenience check whether this picked item is a video.
  bool get isVideo => type == MediaType.video;

  @override
  String toString() =>
      'PickedMedia(path: $path, type: ${type.name}, mime: $mimeType, size: $sizeBytes, ${width}x$height, duration: $duration)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PickedMedia &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          type == other.type &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode =>
      path.hashCode ^ type.hashCode ^ (sizeBytes?.hashCode ?? 0);
}
