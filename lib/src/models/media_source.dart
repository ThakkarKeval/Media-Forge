/// The origin from which media should be obtained.
enum MediaSource {
  /// System photo picker or media gallery.
  gallery,

  /// Device camera capture.
  camera,
}

/// Preferred camera hardware when using [MediaSource.camera].
enum CameraDevice {
  /// Back / rear-facing camera.
  rear,

  /// Front / selfie camera.
  front,
}
