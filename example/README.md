# media_forge_example

Demonstration application for the [`media_forge`](https://pub.dev/packages/media_forge) Flutter plugin.

## Features Demonstrated

* **Single & Multi Photo Picking**: Native gallery selection via Android Photo Picker and iOS `PHPickerViewController`.
* **Camera Capture**: Photo and video capture with preferred camera lens (front/rear).
* **Pre-selection Validation**: Enforcing maximum file sizes and allowed MIME types via `PickerValidator`.
* **Image Optimization & Processing**: Resizing, quality compression, stripping GPS EXIF metadata, and iterative byte-budget searching (`targetSizeBytes`).
* **Video Inspection**: Instant native extraction of video dimensions, duration, orientation, and MIME type.
* **Video Frame Thumbnails**: Extracting frame images at specific offsets (`atTime`) with dimension constraints.
* **Bounded-Concurrency Batch Processing**: Processing multiple images concurrently with live progress streams (`ProcessingEvent`) and cancellation support.
* **Android Activity Recreation Recovery**: Testing state recovery via `retrieveLostData()`.

## Running the Example

### Android
```bash
flutter run -d android
```

### iOS
```bash
cd ios && pod install && cd ..
flutter run -d ios
```
