import 'media_source.dart';

/// Configuration options and constraints for media selection or capture.
class MediaSelectionOptions {
  /// Constructs a [MediaSelectionOptions] constraint set.
  const MediaSelectionOptions({
    this.maxItems,
    this.maxSizeBytes,
    this.maxWidth,
    this.maxHeight,
    this.maxDuration,
    this.allowedMimeTypes,
    this.preferredCameraDevice = CameraDevice.rear,
  });

  /// Maximum number of items permitted when picking multiple media.
  final int? maxItems;

  /// Maximum permitted file size in bytes. Items exceeding this fail validation.
  final int? maxSizeBytes;

  /// Maximum permitted pixel width.
  final int? maxWidth;

  /// Maximum permitted pixel height.
  final int? maxHeight;

  /// Maximum permitted video duration. Videos exceeding this fail validation.
  final Duration? maxDuration;

  /// Explicit list of allowed MIME types (e.g. `['image/jpeg', 'image/png']`).
  final List<String>? allowedMimeTypes;

  /// Preferred hardware camera when launching the camera interface.
  final CameraDevice preferredCameraDevice;
}
