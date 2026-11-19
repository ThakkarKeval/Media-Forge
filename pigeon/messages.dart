import 'package:pigeon/pigeon.dart';

// This file defines the Pigeon bridge contracts between Dart and native host platforms.
// To regenerate files, run:
//   dart run pigeon --input pigeon/messages.dart

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'media_forge',
    dartOut: 'lib/src/messages.g.dart',
    cppHeaderOut: 'windows/messages.g.h',
    cppSourceOut: 'windows/messages.g.cpp',
    cppOptions: CppOptions(namespace: 'media_forge'),
    gobjectHeaderOut: 'linux/messages.g.h',
    gobjectSourceOut: 'linux/messages.g.cc',
    kotlinOut: 'android/src/main/kotlin/com/cavernlabs/media/forge/media_forge/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.cavernlabs.media.forge.media_forge',
    ),
    swiftOut: [
      'ios/media_forge/Sources/media_forge/Messages.g.swift',
      'macos/media_forge/Sources/media_forge/Messages.g.swift',
    ],
  ),
)
enum NativeMediaType { image, video, mixed }

enum NativeMediaSource { gallery, camera }

enum NativeCameraDevice { rear, front }

class NativePickerOptions {
  NativePickerOptions({
    this.maxItems,
    this.cameraDevice,
    this.maxDurationSeconds,
  });

  int? maxItems;
  NativeCameraDevice? cameraDevice;
  int? maxDurationSeconds;
}

class NativePickedMedia {
  NativePickedMedia({
    required this.path,
    required this.type,
    this.name,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
  });

  String path;
  NativeMediaType type;
  String? name;
  String? mimeType;
  int? sizeBytes;
  int? width;
  int? height;
  int? durationMs;
}

class NativeLostDataResponse {
  NativeLostDataResponse({
    required this.items,
    this.errorCode,
    this.errorMessage,
  });

  List<NativePickedMedia> items;
  String? errorCode;
  String? errorMessage;
}

class NativeImageProcessOptions {
  NativeImageProcessOptions({
    this.maxWidth,
    this.maxHeight,
    this.quality,
    this.targetSizeBytes,
    this.stripGpsMetadata,
    this.format,
    this.outputFileName,
  });

  int? maxWidth;
  int? maxHeight;
  int? quality;
  int? targetSizeBytes;
  bool? stripGpsMetadata;
  String? format;
  String? outputFileName;
}

class NativeProcessedMedia {
  NativeProcessedMedia({
    required this.path,
    required this.originalPath,
    this.mimeType,
    this.sizeBytes,
    this.originalSizeBytes,
    this.width,
    this.height,
    required this.changed,
    this.targetMet,
  });

  String path;
  String originalPath;
  String? mimeType;
  int? sizeBytes;
  int? originalSizeBytes;
  int? width;
  int? height;
  bool changed;
  bool? targetMet;
}

class NativeVideoMetadata {
  NativeVideoMetadata({
    required this.path,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
    this.rotationDegrees,
  });

  String path;
  String? mimeType;
  int? sizeBytes;
  int? width;
  int? height;
  int? durationMs;
  int? rotationDegrees;
}

@HostApi()
abstract class MediaForgePluginApi {
  String getPlatformVersion();
}

@HostApi()
abstract class MediaForgePickerApi {
  @async
  NativePickedMedia? pickImage(
    NativeMediaSource source,
    NativePickerOptions? options,
  );

  @async
  NativePickedMedia? pickVideo(
    NativeMediaSource source,
    NativePickerOptions? options,
  );

  @async
  List<NativePickedMedia> pickMultiple(
    NativeMediaType type,
    NativePickerOptions? options,
  );

  @async
  NativeLostDataResponse retrieveLostData();
}

@HostApi()
abstract class MediaForgeProcessorApi {
  @async
  NativeProcessedMedia processImage(
    String path,
    NativeImageProcessOptions options,
  );

  @async
  NativeVideoMetadata inspectVideo(String path);

  @async
  String createVideoThumbnail(
    String videoPath,
    int atMs,
    int? maxWidth,
    int? maxHeight,
  );

  @async
  bool clearCache();
}
