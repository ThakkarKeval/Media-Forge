/// Supported target image formats for conversion and encoding.
enum ImageFormat {
  /// Joint Photographic Experts Group (lossy, no alpha channel).
  jpeg,

  /// Portable Network Graphics (lossless, preserves alpha channel).
  png,

  /// WebP format (lossy or lossless, efficient compression).
  webp,
}

/// Configuration options for image optimization, resizing, and conversion.
class ImageProcessingOptions {
  /// Constructs an [ImageProcessingOptions] configuration.
  const ImageProcessingOptions({
    this.maxWidth,
    this.maxHeight,
    this.quality = 85,
    this.targetSizeBytes,
    this.stripGpsMetadata = true,
    this.format,
    this.outputFileName = 'media_forge_opt',
    this.preserveAspectRatio = true,
    this.allowUpscaling = false,
  }) : assert(
         quality == null || (quality >= 1 && quality <= 100),
         'Quality must be between 1 and 100 inclusive',
       );

  /// Target maximum width in pixels.
  final int? maxWidth;

  /// Target maximum height in pixels.
  final int? maxHeight;

  /// Lossy compression quality factor from 1 to 100. Defaults to 85.
  /// Has no effect on lossless formats (like PNG).
  final int? quality;

  /// Desired maximum target file size in bytes.
  /// If provided, optimization will perform a best-effort iterative search
  /// to meet or approach this target without reducing dimensions further.
  final int? targetSizeBytes;

  /// Whether to remove GPS/location coordinates from EXIF headers for privacy.
  /// Defaults to `true`.
  final bool stripGpsMetadata;

  /// Optional target format to convert the image into.
  /// If null, preserves original format if supported, or defaults to JPEG.
  final ImageFormat? format;

  /// Custom destination file name (e.g. `user_avatar` or `custom_photo.jpg`).
  /// Defaults to `'media_forge_opt'`.
  /// If specified without an extension, the appropriate extension for the
  /// target format will be automatically appended.
  final String? outputFileName;

  /// Whether resizing preserves the original aspect ratio. Defaults to `true`.
  final bool preserveAspectRatio;

  /// Whether resizing is allowed to upscale smaller images. Defaults to `false`.
  final bool allowUpscaling;

  @override
  String toString() =>
      'ImageProcessingOptions(${maxWidth}x$maxHeight, q: $quality, target: $targetSizeBytes, stripGps: $stripGpsMetadata, format: ${format?.name}, name: $outputFileName)';
}
