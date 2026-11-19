import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_forge/media_forge.dart';
import 'package:media_forge/media_forge_pigeon.dart';
import 'package:media_forge/src/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBatchProcessorApi fakeProcessorApi;
  late PigeonMediaForge pigeonPlatform;
  late Directory tempDir;
  late List<File> files;

  setUp(() async {
    fakeProcessorApi = FakeBatchProcessorApi();
    pigeonPlatform = PigeonMediaForge(
      processorApi: fakeProcessorApi,
    );
    MediaForgePlatform.instance = pigeonPlatform;

    tempDir = await Directory.systemTemp.createTemp('media_forge_batch_test_');
    files = [];
    for (int i = 0; i < 5; i++) {
      final f = File('${tempDir.path}/img_$i.jpg');
      await f.writeAsBytes([1, 2, 3, 4, i]);
      files.add(f);
    }
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BatchJob & Bounded Concurrency Engine', () {
    test('handles empty input batch gracefully', () async {
      final job = MediaProcessor.processImages([]);
      final result = await job.result;

      expect(result.totalCount, 0);
      expect(result.isAllSuccessful, isTrue);
      expect(result.successes, isEmpty);
      expect(result.failures, isEmpty);
    });

    test('processes all items successfully and preserves order', () async {
      final paths = files.map((f) => f.path).toList();
      final job = MediaProcessor.processImages(
        paths,
        options: const ImageProcessingOptions(quality: 80),
        concurrency: 2,
      );

      final events = <ProcessingEvent>[];
      job.events.listen(events.add);

      final result = await job.result;

      expect(result.totalCount, 5);
      expect(result.successCount, 5);
      expect(result.failureCount, 0);
      expect(result.isAllSuccessful, isTrue);
      expect(result.isCancelled, isFalse);

      // Verify order matches input paths
      for (int i = 0; i < 5; i++) {
        expect(result.items[i].inputPath, paths[i]);
        expect(result.items[i].index, i);
        expect(result.items[i].isSuccess, isTrue);
      }

      // Check event progression
      final completedEvents = events
          .where((e) => e.stage == ProcessingStage.completed)
          .toList();
      expect(completedEvents.length, 5);
      expect(completedEvents.last.progressFraction, 1.0);
    });

    test('enforces max concurrent workers limit', () async {
      final paths = files.map((f) => f.path).toList();
      fakeProcessorApi.delay = const Duration(milliseconds: 30);

      final job = MediaProcessor.processImages(
        paths,
        concurrency: 2,
      );

      await job.result;

      expect(fakeProcessorApi.maxConcurrentObserved, lessThanOrEqualTo(2));
      expect(fakeProcessorApi.maxConcurrentObserved, greaterThanOrEqualTo(1));
    });

    test('tolerates missing files without crashing batch', () async {
      final validPath = files[0].path;
      const invalidPath = '/non/existent/missing.jpg';

      final job = MediaProcessor.processImages(
        [validPath, invalidPath],
        concurrency: 1,
      );

      final result = await job.result;

      expect(result.totalCount, 2);
      expect(result.successCount, 1);
      expect(result.failureCount, 1);
      expect(result.isAllSuccessful, isFalse);

      expect(result.items[0].isSuccess, isTrue);
      expect(result.items[1].isSuccess, isFalse);
      expect(result.items[1].error?.code, MediaForgeErrorCode.fileNotFound);
    });

    test('supports job cancellation cleanly', () async {
      final paths = files.map((f) => f.path).toList();
      fakeProcessorApi.delay = const Duration(milliseconds: 50);

      final job = MediaProcessor.processImages(
        paths,
        concurrency: 1,
      );

      // Cancel after brief moment
      Timer(const Duration(milliseconds: 20), () {
        job.cancel();
      });

      final result = await job.result;

      expect(job.isCancelled, isTrue);
      expect(result.isCancelled, isTrue);
      expect(result.isAllSuccessful, isFalse);
    });
  });
}

class FakeBatchProcessorApi extends MediaForgeProcessorApi {
  Duration delay = Duration.zero;
  int currentActive = 0;
  int maxConcurrentObserved = 0;

  @override
  Future<NativeProcessedMedia> processImage(
    String path,
    NativeImageProcessOptions options,
  ) async {
    currentActive++;
    if (currentActive > maxConcurrentObserved) {
      maxConcurrentObserved = currentActive;
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    currentActive--;

    return NativeProcessedMedia(
      path: '${path}_opt.jpg',
      originalPath: path,
      changed: true,
      sizeBytes: 100,
      originalSizeBytes: 200,
    );
  }

  @override
  Future<NativeVideoMetadata> inspectVideo(String path) async {
    return NativeVideoMetadata(path: path);
  }

  @override
  Future<String> createVideoThumbnail(
    String videoPath,
    int atMs,
    int? maxWidth,
    int? maxHeight,
  ) async {
    return '${videoPath}_thumb.jpg';
  }

  @override
  Future<bool> clearCache() async {
    return true;
  }
}
