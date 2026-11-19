/// Stable error codes representing categories of failures in MediaForge.
enum MediaForgeErrorCode {
  /// The user cancelled the operation.
  cancelled,

  /// Required platform permissions (e.g., Camera or Photos) were denied.
  permissionDenied,

  /// The specified media file was not found or is inaccessible.
  fileNotFound,

  /// Selection or input constraints were violated (e.g., file size, dimensions, count).
  validationFailed,

  /// The media format is not supported on this platform.
  unsupportedFormat,

  /// An error occurred during image or video processing.
  processingFailed,

  /// Best-effort optimization could not meet the target size constraint.
  targetUnreachable,

  /// An unclassified native platform error occurred.
  platformFailure,
}
