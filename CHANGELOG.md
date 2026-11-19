## 0.1.0

Initial release of `media_forge`: a dependable, local-only Flutter plugin for picking, validating, and optimizing photos and inspecting videos on Android and iOS.

### Features
* **Media Picker (`MediaPicker`)**:
  * Photo & video selection from system gallery (`PHPickerViewController` on iOS, Android Photo Picker / GET_CONTENT fallback on Android).
  * Direct camera photo and video capture with device selection (front/rear) and maximum duration limits.
  * Multi-item selection with configurable `maxItems`.
  * Pre-processing client-side validation (`PickerValidator`) checking file existence, size constraints, allowed MIME types, and dimensions.
  * Android Activity recreation recovery via `retrieveLostData()`.
* **Image Processor (`MediaProcessor`)**:
  * Proportional dimension downscaling (`maxWidth`, `maxHeight`).
  * Lossy image compression (`quality: 1-100`) and format conversion (JPEG, PNG, WebP, HEIC).
  * Output filename customization (`outputFileName`) with automatic extension resolution.
  * Binary-search iterative target byte budgeting (`targetSizeBytes`) with `targetMet` outcome reporting.
  * EXIF orientation normalization and GPS metadata stripping.
  * Safe intermediate caching with `clearCache()` and zero mutations to original source files.
* **Video Inspection & Thumbnails**:
  * High-performance video metadata inspection (`width`, `height`, `duration`, `sizeBytes`, `rotationDegrees`, `mimeType`) via `MediaMetadataRetriever` (Android) and `AVURLAsset` (iOS).
  * Video frame thumbnail generation at any offset (`atTime`) with dimension constraints.
  * Strict v0.1 scope boundary: inspection and thumbnails only (no transcoding or compression).
* **Bounded-Concurrency Batch Engine (`BatchJob`)**:
  * Process collections of images with bounded worker pools (`concurrency: 2`).
  * Live broadcast progress event stream (`ProcessingEvent`) with honest completed fractions.
  * Non-blocking cancellation token support (`job.cancel()`).
  * Individual error isolation preserving original item ordering in `BatchResult`.
* **Zero Cloud/Network Footprint**: Zero HTTP requests, analytics, or remote dependencies.
