import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_forge/media_forge.dart';
import 'package:media_forge/media_forge_pigeon.dart';
import 'package:media_forge/src/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMediaForgeProcessorApi fakeProcessorApi;
  late PigeonMediaForge pigeonPlatform;
  late Directory tempDir;
  late File sampleVideo;

  setUp(() async {
    fakeProcessorApi = FakeMediaForgeProcessorApi();
    pigeonPlatform = PigeonMediaForge(
      processorApi: fakeProcessorApi,
    );
    MediaForgePlatform.instance = pigeonPlatform;

    tempDir = await Directory.systemTemp.createTemp('media_forge_video_test_');
    sampleVideo = File('${tempDir.path}/sample.mp4');
    await sampleVideo.writeAsBytes([0, 0, 0, 32, 102, 116, 121, 112]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Video Inspection & Thumbnails', () {
    test('throws fileNotFound if path is empty or file does not exist', () async {
      expect(
        () => MediaProcessor.inspectVideo(''),
        throwsA(
          isA<MediaForgeException>().having(
            (e) => e.code,
            'code',
            MediaForgeErrorCode.fileNotFound,
          ),
        ),
      );

      expect(
        () => MediaProcessor.inspectVideo('/non/existent/clip.mp4'),
        throwsA(
          isA<MediaForgeException>().having(
            (e) => e.code,
            'code',
            MediaForgeErrorCode.fileNotFound,
          ),
        ),
      );
    });

    test('inspectVideo returns structured VideoMetadata', () async {
      fakeProcessorApi.nextVideoMetadata = NativeVideoMetadata(
        path: sampleVideo.path,
        mimeType: 'video/mp4',
        sizeBytes: 1048576,
        width: 1920,
        height: 1080,
        durationMs: 15200,
        rotationDegrees: 90,
      );

      final meta = await MediaProcessor.inspectVideo(sampleVideo.path);
      expect(meta.path, sampleVideo.path);
      expect(meta.mimeType, 'video/mp4');
      expect(meta.sizeBytes, 1048576);
      expect(meta.width, 1920);
      expect(meta.height, 1080);
      expect(meta.duration, const Duration(milliseconds: 15200));
      expect(meta.rotationDegrees, 90);
      expect(meta.aspectRatio, closeTo(1920 / 1080, 0.001));
      expect(meta.file.existsSync(), isTrue);
    });

    test('createVideoThumbnail returns thumbnail image path', () async {
      fakeProcessorApi.nextThumbnailPath = '${tempDir.path}/thumb.jpg';

      final thumbPath = await MediaProcessor.createVideoThumbnail(
        videoPath: sampleVideo.path,
        atTime: const Duration(seconds: 2),
        maxWidth: 320,
      );

      expect(thumbPath, '${tempDir.path}/thumb.jpg');
      expect(fakeProcessorApi.lastThumbnailAtMs, 2000);
      expect(fakeProcessorApi.lastThumbnailMaxWidth, 320);
    });

    test('facade convenience helpers forward to processor', () async {
      fakeProcessorApi.nextVideoMetadata = NativeVideoMetadata(
        path: sampleVideo.path,
        width: 1280,
        height: 720,
        durationMs: 5000,
      );

      final meta = await MediaForge.inspectVideo(sampleVideo.path);
      expect(meta.width, 1280);
      expect(meta.height, 720);
    });
  });
}

class FakeMediaForgeProcessorApi extends MediaForgeProcessorApi {
  NativeProcessedMedia? nextProcessedMedia;
  NativeVideoMetadata? nextVideoMetadata;
  String? nextThumbnailPath;
  int? lastThumbnailAtMs;
  int? lastThumbnailMaxWidth;

  @override
  Future<NativeProcessedMedia> processImage(
    String path,
    NativeImageProcessOptions options,
  ) async {
    return nextProcessedMedia ??
        NativeProcessedMedia(path: path, originalPath: path, changed: false);
  }

  @override
  Future<NativeVideoMetadata> inspectVideo(String path) async {
    return nextVideoMetadata ?? NativeVideoMetadata(path: path);
  }

  @override
  Future<String> createVideoThumbnail(
    String videoPath,
    int atMs,
    int? maxWidth,
    int? maxHeight,
  ) async {
    lastThumbnailAtMs = atMs;
    lastThumbnailMaxWidth = maxWidth;
    return nextThumbnailPath ?? '${videoPath}_thumb.jpg';
  }

  @override
  Future<bool> clearCache() async {
    return true;
  }
}
