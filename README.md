# MediaForge

A dependable, local-only Flutter plugin for picking, validating, and optimizing photos and inspecting videos on **Android** and **iOS**.

Designed with a strict separation between media selection and media processing, **MediaForge** leaves original files untouched, strips sensitive GPS metadata by default, enforces byte budgeting, and processes multiple items through a bounded-concurrency batch engine.

---

## ⚡ Core Philosophy & Guarantees

1. **Local-Only & Zero Cloud**: Completely free of network calls, cloud uploaders, telemetry, or remote dependencies.
2. **Clean Separation of Concerns**: `MediaPicker` handles selection/capture; `MediaProcessor` handles transformations. You can pick without processing or process without picking.
3. **Non-Destructive**: Never mutates or overwrites user originals. Outputs are placed in managed application cache directories with cleanup via `MediaForge.clearCache()`.
4. **Scope Integrity**: MediaForge v0.1 does **not** transcode or re-encode video. Video features are strictly **inspection** (duration, dimensions, file size, rotation, MIME type) and **thumbnail frame extraction**.
5. **Memory-Conscious Batching**: Batch processing runs through a bounded worker pool (default `concurrency: 2`) with cancellation tokens and measurable progress streams.

---

## 📱 Platform Setup

### Android

1. **Camera Permission**: If using camera capture, declare camera permission in your `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

2. **FileProvider**: MediaForge bundles its own `FileProvider` (`com.cavernlabs.media.forge.media_forge.provider`) using a dedicated cache subfolder (`cache/media_forge_camera/`), preventing authority collisions with other plugins.

### iOS

Add camera and photo library usage descriptions in `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to capture photos and videos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app requires access to your photo library to select photos and videos.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app requires microphone access when recording videos.</string>
```

---

## 🚀 Quick Start

### 1. Picking Media

```dart
import 'package:media_forge/media_forge.dart';

// Single Photo from Gallery
final PickedMedia? photo = await MediaForge.pickImage(
  source: MediaSource.gallery,
);

// Photo from Camera (Preferred Front or Rear)
final PickedMedia? captured = await MediaForge.pickImage(
  source: MediaSource.camera,
  preferredCameraDevice: CameraDevice.front,
);

// Multiple Photos or Videos
final List<PickedMedia> items = await MediaForge.pickMultiple(
  type: MediaType.image, // or MediaType.video / MediaType.mixed
  maxItems: 5,
);
```

### 2. Client-Side Validation

Validate media constraints before performing heavy operations:

```dart
final PickedMedia? validPhoto = await MediaForge.pickImage(
  source: MediaSource.gallery,
  options: const MediaSelectionOptions(
    maxSizeBytes: 5 * 1024 * 1024, // 5 MB max
    allowedMimeTypes: ['image/jpeg', 'image/png'],
  ),
);
```

### 3. Image Processing & Optimization

Downscale, compress, meet target byte limits, and strip GPS EXIF:

```dart
final ProcessedMedia processed = await MediaForge.processImage(
  photo.path,
  options: const ImageProcessingOptions(
    maxWidth: 1920,
    maxHeight: 1080,
    quality: 80,
    targetSizeBytes: 300 * 1024, // Budget: 300 KB
    stripGpsMetadata: true,      // Privacy default
    format: ImageFormat.jpeg,
  ),
);

print('Path: ${processed.path}');
print('Saved: ${processed.savingsBytes} bytes (${processed.savingsPercentage?.toStringAsFixed(1)}%)');
print('Target Met: ${processed.targetMet}');
```

Or pick and optimize in one step:
```dart
final ProcessedMedia? optimized = await MediaForge.pickAndProcessImage(
  source: MediaSource.gallery,
  processingOptions: const ImageProcessingOptions(
    maxWidth: 1280,
    quality: 75,
  ),
);
```

### 4. Bounded-Concurrency Batch Engine

Optimize multiple images concurrently without exhausting device memory:

```dart
final BatchJob job = MediaForge.processImages(
  ['/path/to/img1.jpg', '/path/to/img2.jpg', '/path/to/img3.jpg'],
  options: const ImageProcessingOptions(maxWidth: 1280, quality: 75),
  concurrency: 2, // Bounded parallel workers
);

// Listen to measurable progress events
job.events.listen((ProcessingEvent event) {
  print('Item ${event.itemIndex + 1}/${event.totalCount} [${event.stage.name}]');
  print('Progress: ${((event.progressFraction ?? 0) * 100).toStringAsFixed(0)}%');
});

// Await final aggregated outcome (preserves input order)
final BatchResult<ProcessedMedia> result = await job.result;
print('Successes: ${result.successCount}, Failures: ${result.failureCount}');

// Cancel at any time
// job.cancel();
```

### 5. Video Inspection & Thumbnails

Inspect video attributes and extract frame thumbnails:

```dart
// Inspect video metadata (fast native inspection)
final VideoMetadata meta = await MediaForge.inspectVideo(videoPath);
print('Dimensions: ${meta.width}x${meta.height}');
print('Duration: ${meta.duration?.inSeconds}s');
print('Rotation: ${meta.rotationDegrees}°');

// Extract thumbnail frame at 1.5 seconds
final String thumbnailPath = await MediaForge.createVideoThumbnail(
  videoPath: videoPath,
  atTime: const Duration(milliseconds: 1500),
  maxWidth: 400,
  maxHeight: 400,
);
```

### 6. Android Activity Recreation Recovery

Safely recover captured media if the Android OS killed your Activity while the camera was open:

```dart
@override
void initState() {
  super.initState();
  _recoverLostMedia();
}

Future<void> _recoverLostMedia() async {
  final LostDataResponse response = await MediaForge.retrieveLostData();
  if (response.items.isNotEmpty) {
    print('Recovered ${response.items.length} items from previous session');
  } else if (response.exception != null) {
    print('Camera error prior to death: ${response.exception!.message}');
  }
}
```

### 7. Cache Management

Clean up intermediate processed files whenever appropriate:

```dart
await MediaForge.clearCache();
```

---

## 🧪 Testing

MediaForge comes with 100% mocked platform interface tests and unit tests:

```bash
flutter test
```

Android native tests:
```bash
cd example/android && ./gradlew testDebugUnitTest
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
