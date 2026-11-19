# Media Forge — Architecture & Technical Design

## 1. Overview & Core Mission

`media_forge` is an independent, dependable Flutter plugin for picking and processing local photos and videos on Android and iOS. It has zero cloud, network, or upload provider dependencies. Output files are local, app-controlled files with typed metadata suitable for consumption by any downstream storage or upload solution (such as `s3_transfer_kit` or a custom HTTP client).

## 2. Architectural Principles

1. **Independent Modules**: `MediaPicker` and `MediaProcessor` are completely decoupled and independently usable. A unified `MediaForge` facade provides convenience shortcuts without coupling the underlying subsystems.
2. **Type-Safe Platform Bridge (Pigeon)**: Platform communication between Dart and native host code (Kotlin on Android, Swift on iOS) is governed by Pigeon contracts. This eliminates stringly-typed MethodChannel errors, guarantees null-safety, and provides typed exception handling.
3. **Immutability of Original Assets**: Any transformation writes to a new, uniquely named file in app-managed temporary storage. The original asset is never overwritten by default.
4. **Zero Cloud Dependencies**: The plugin neither requests network permissions nor interacts with any remote endpoints.
5. **Resource & Memory Safety**: Large files and image streams are processed natively to avoid blowing up the Dart VM memory heap. Platform channels carry file paths and metadata descriptors, never raw image/video byte arrays.
6. **Privacy First**: Modern photo pickers (`PickVisualMedia` on Android, `PHPickerViewController` on iOS) are prioritized to avoid requiring broad read/write storage permissions. Location/GPS EXIF stripping is natively supported.

## 3. Directory Layout

```text
media_forge/
├── lib/
│   ├── media_forge.dart                 # Main export & optional convenience facade
│   └── src/
│       ├── models/                      # Immutable data classes & configuration
│       │   ├── picked_media.dart
│       │   ├── media_type.dart
│       │   ├── media_source.dart
│       │   ├── selection_options.dart
│       │   ├── image_options.dart
│       │   ├── processed_media.dart
│       │   ├── video_metadata.dart
│       │   └── batch_result.dart
│       ├── errors/                      # Typed error taxonomy
│       │   ├── media_forge_exception.dart
│       │   └── error_codes.dart
│       ├── picker/                      # Selection & capture subsystem
│       │   ├── media_picker.dart
│       │   └── picker_validator.dart
│       ├── processor/                   # Image optimization & video inspection
│       │   └── media_processor.dart     # (Milestones 2 & 3)
│       └── platform/                    # Pigeon bridge & platform interface
│           ├── messages.g.dart          # Pigeon generated Dart bridge
│           └── media_forge_platform.dart
├── pigeon/
│   └── messages.dart                    # Pigeon contract definitions
├── android/                             # Android Kotlin implementation
│   └── src/main/kotlin/.../
│       ├── MediaForgePlugin.kt          # Flutter plugin lifecycle & engine binding
│       ├── MediaForgePicker.kt          # Photo picker, camera, & lost-data recovery
│       ├── MediaForgeProcessor.kt       # Exif, resizing, & video metadata
│       └── Messages.g.kt                # Pigeon generated Kotlin bridge
├── ios/                                 # iOS Swift implementation
│   └── Sources/media_forge/
│       ├── MediaForgePlugin.swift       # Flutter plugin lifecycle & delegate
│       ├── MediaForgePicker.swift       # PHPicker & UIImagePickerController
│       ├── MediaForgeProcessor.swift    # ImageIO, CoreGraphics, & AVFoundation
│       └── Messages.g.swift             # Pigeon generated Swift bridge
├── test/                                # Dart unit tests
└── example/                             # Runnable Flutter demo app
```

## 4. Bridge Design (Pigeon Contracts)

Pigeon defines two primary host APIs and an optional callback/event API:
- `MediaForgePickerApi`: Handles single/multiple image selection, video selection, mixed visual media selection, camera capture, and Android lost-activity recovery.
- `MediaForgeProcessorApi`: Handles image resizing, format conversion, EXIF orientation/location stripping, best-effort target-size compression, and video inspection / thumbnail extraction.

All operations return typed data classes (`PigeonPickedMedia`, `PigeonVideoMetadata`, `PigeonProcessedMedia`) containing filesystem paths, MIME types, file sizes, and dimensional/duration attributes.

## 5. Subsystem Details

### 5.1 Picker Subsystem (`MediaPicker`)
- **Android**: Uses `ActivityResultContracts.PickVisualMedia` and `ActivityResultContracts.PickMultipleVisualMedia` backed by Google Play Services / Android 13+ system photo picker. Falls back cleanly to `ACTION_GET_CONTENT` or `ACTION_OPEN_DOCUMENT` on legacy devices without Play Services. Captures photos/videos via `MediaStore.ACTION_IMAGE_CAPTURE` / `MediaStore.ACTION_VIDEO_CAPTURE` with file provider URI.
- **Android Lost Data Recovery**: Implements `PluginRegistry.ActivityResultListener` and caches unconsumed results when Android OS terminates the host activity under memory pressure. Dart callers can retrieve lost selections via `MediaPicker.retrieveLostData()`.
- **iOS**: Uses `PHPickerViewController` (iOS 14+) which requires zero photo library permissions. Captures media via `UIImagePickerController`.
- **Validation**: `PickerValidator` enforces maximum items, allowed MIME types, max file sizes, and video duration constraints with explicit typed validation errors (`MediaForgeErrorCode.validationFailed`).

### 5.2 Processor Subsystem (`MediaProcessor`) *(M2 - M3)*
- Independent of picker: Accepts any valid local filesystem path.
- Processes on background native threads (Kotlin Coroutines / Dispatchers.IO on Android, GCD on iOS).
- Native orientation normalization via EXIF headers.
- Transparent alpha channel preservation (PNG/WebP) vs. explicit background fill or error for JPEG.

## 6. Error Handling Taxonomy

Every failure is surfaced as a typed `MediaForgeException` containing:
- `code`: `MediaForgeErrorCode` (`cancelled`, `permissionDenied`, `fileNotFound`, `validationFailed`, `unsupportedFormat`, `processingFailed`, `targetUnreachable`, `platformFailure`).
- `message`: Clear human-readable description of the root cause.
- `details`: Optional underlying platform or context information.

User cancellations (e.g., closing picker without selecting) return `null` or an empty list in standard pick methods rather than throwing, avoiding unhandled exception churn. Explicit cancellation errors are reserved for cancelled active processing jobs.

## 7. Storage & Lifecycle Contract

- Intermediates and captured files are placed inside the application's temporary directory (`cacheDir` on Android, `NSTemporaryDirectory()` on iOS).
- Clean up API: `MediaForge.clearCache()` removes managed temporary outputs when requested.
- Returned files remain valid for the lifespan of the host app execution or until explicit cleanup.
