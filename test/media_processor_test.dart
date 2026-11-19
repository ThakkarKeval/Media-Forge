import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_forge/media_forge.dart';
import 'package:media_forge/media_forge_pigeon.dart';
import 'package:media_forge/src/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMediaForgeProcessorApi fakeProcessorApi;
  late FakeMediaForgePickerApi fakePickerApi;
  late PigeonMediaForge pigeonPlatform;
  late Directory tempDir;
  late File sampleFile;

  setUp(() async {
    fakeProcessorApi = FakeMediaForgeProcessorApi();
    fakePickerApi = FakeMediaForgePickerApi();
    pigeonPlatform = PigeonMediaForge(
      pickerApi: fakePickerApi,
      processorApi: fakeProcessorApi,
    );
    MediaForgePlatform.instance = pigeonPlatform;

    tempDir = await Directory.systemTemp.createTemp('media_forge_test_');
    sampleFile = File('${tempDir.path}/sample.jpg');
    await sampleFile.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MediaProcessor', () {
    test('throws fileNotFound when path is empty or does not exist', () async {
      expect(
        () => MediaProcessor.processImage(''),
        throwsA(
          isA<MediaForgeException>().having(
            (e) => e.code,
            'code',
            MediaForgeErrorCode.fileNotFound,
          ),
        ),
      );

      expect(
        () => MediaProcessor.processImage('/non/existent/path/photo.jpg'),
        throwsA(
          isA<MediaForgeException>().having(
            (e) => e.code,
            'code',
            MediaForgeErrorCode.fileNotFound,
          ),
        ),
      );
    });

    test('processes image and returns ProcessedMedia with savings', () async {
      fakeProcessorApi.nextProcessedMedia = NativeProcessedMedia(
        path: '${tempDir.path}/optimized.jpg',
        originalPath: sampleFile.path,
        mimeType: 'image/jpeg',
        sizeBytes: 4000,
        originalSizeBytes: 10000,
        width: 1920,
        height: 1080,
        changed: true,
        targetMet: true,
      );

      final result = await MediaProcessor.processImage(
        sampleFile.path,
        options: const ImageProcessingOptions(
          maxWidth: 1920,
          quality: 80,
          targetSizeBytes: 5000,
          outputFileName: 'my_custom_photo',
        ),
      );

      expect(result.path, '${tempDir.path}/optimized.jpg');
      expect(fakeProcessorApi.lastOptions?.outputFileName, 'my_custom_photo');
      expect(result.originalPath, sampleFile.path);
      expect(result.sizeBytes, 4000);
      expect(result.originalSizeBytes, 10000);
      expect(result.savingsBytes, 6000);
      expect(result.savingsPercentage, 60.0);
      expect(result.changed, isTrue);
      expect(result.targetMet, isTrue);
    });

    test('handles smart passthrough reporting', () async {
      fakeProcessorApi.nextProcessedMedia = NativeProcessedMedia(
        path: sampleFile.path,
        originalPath: sampleFile.path,
        mimeType: 'image/jpeg',
        sizeBytes: 8,
        originalSizeBytes: 8,
        width: 800,
        height: 600,
        changed: false,
      );

      final result = await MediaProcessor.processImage(sampleFile.path);
      expect(result.changed, isFalse);
      expect(result.savingsBytes, 0);
      expect(result.savingsPercentage, 0.0);
      expect(result.targetMet, isNull);
    });

    test('clearCache delegates to platform', () async {
      fakeProcessorApi.clearCacheResult = true;
      final result = await MediaProcessor.clearCache();
      expect(result, isTrue);
    });

    test(
      'facade processImage and pickAndProcessImage delegate correctly',
      () async {
        fakePickerApi.nextPickedImage = NativePickedMedia(
          path: sampleFile.path,
          type: NativeMediaType.image,
        );

        fakeProcessorApi.nextProcessedMedia = NativeProcessedMedia(
          path: '${tempDir.path}/picked_opt.jpg',
          originalPath: sampleFile.path,
          changed: true,
        );

        final result = await MediaForge.pickAndProcessImage(
          source: MediaSource.gallery,
          processingOptions: const ImageProcessingOptions(quality: 75),
        );

        expect(result, isNotNull);
        expect(result!.path, '${tempDir.path}/picked_opt.jpg');
      },
    );
  });
}

class FakeMediaForgeProcessorApi implements MediaForgeProcessorApi {
  NativeProcessedMedia? nextProcessedMedia;
  NativeImageProcessOptions? lastOptions;
  bool clearCacheResult = true;
  Object? errorToThrow;

  @override
  Future<NativeProcessedMedia> processImage(
    String path,
    NativeImageProcessOptions options,
  ) async {
    lastOptions = options;
    if (errorToThrow != null) throw errorToThrow!;
    return nextProcessedMedia ??
        NativeProcessedMedia(path: path, originalPath: path, changed: false);
  }

  @override
  Future<NativeVideoMetadata> inspectVideo(String path) async {
    throw UnimplementedError();
  }

  @override
  Future<String> createVideoThumbnail(
    String videoPath,
    int atMs,
    int? maxWidth,
    int? maxHeight,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> clearCache() async {
    if (errorToThrow != null) throw errorToThrow!;
    return clearCacheResult;
  }

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';
}

class FakeMediaForgePickerApi implements MediaForgePickerApi {
  NativePickedMedia? nextPickedImage;

  @override
  Future<NativePickedMedia?> pickImage(
    NativeMediaSource source,
    NativePickerOptions? options,
  ) async {
    return nextPickedImage;
  }

  @override
  Future<NativePickedMedia?> pickVideo(
    NativeMediaSource source,
    NativePickerOptions? options,
  ) async {
    return null;
  }

  @override
  Future<List<NativePickedMedia>> pickMultiple(
    NativeMediaType type,
    NativePickerOptions? options,
  ) async {
    return [];
  }

  @override
  Future<NativeLostDataResponse> retrieveLostData() async {
    return NativeLostDataResponse(items: []);
  }

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';
}
