import 'dart:async';
import 'dart:io';

import '../errors/error_codes.dart';
import '../errors/media_forge_exception.dart';
import '../models/batch_result.dart';
import '../models/image_options.dart';
import '../models/processed_media.dart';
import 'media_processor.dart';

/// Represents an ongoing batch processing job with cancellation support
/// and progress reporting.
class BatchJob {
  BatchJob._({
    required List<String> paths,
    required this.options,
    required int concurrency,
  })  : _paths = List.unmodifiable(paths),
        _concurrency = concurrency > 0 ? concurrency : 1 {
    _start();
  }

  /// Starts a bounded-concurrency batch processing job for [paths].
  static BatchJob start({
    required List<String> paths,
    ImageProcessingOptions options = const ImageProcessingOptions(),
    int concurrency = 2,
  }) {
    return BatchJob._(
      paths: paths,
      options: options,
      concurrency: concurrency,
    );
  }

  final List<String> _paths;

  /// The options applied to each image in this batch job.
  final ImageProcessingOptions options;

  final int _concurrency;

  final StreamController<ProcessingEvent> _eventsController =
      StreamController<ProcessingEvent>.broadcast();
  final Completer<BatchResult<ProcessedMedia>> _completer =
      Completer<BatchResult<ProcessedMedia>>();

  bool _isCancelled = false;
  int _completedCount = 0;

  /// A broadcast stream of [ProcessingEvent]s emitted during batch lifecycle.
  Stream<ProcessingEvent> get events => _eventsController.stream;

  /// A future that completes with the aggregated [BatchResult] when all items
  /// have been processed or when processing is cancelled.
  Future<BatchResult<ProcessedMedia>> get result => _completer.future;

  /// Whether the job has received a cancellation request.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation of all remaining queued and pending items.
  void cancel() {
    if (_isCancelled || _completer.isCompleted) return;
    _isCancelled = true;
  }

  Future<void> _start() async {
    final total = _paths.length;
    if (total == 0) {
      const emptyResult = BatchResult<ProcessedMedia>(items: []);
      _completer.complete(emptyResult);
      await _eventsController.close();
      return;
    }

    final itemResults = List<BatchItemResult<ProcessedMedia>?>.filled(
      total,
      null,
    );

    // Initial queued events for all items
    for (int i = 0; i < total; i++) {
      _emit(
        ProcessingEvent(
          stage: ProcessingStage.queued,
          itemPath: _paths[i],
          itemIndex: i,
          completedCount: 0,
          totalCount: total,
          progressFraction: 0.0,
        ),
      );
    }

    var nextIndex = 0;
    var activeWorkers = 0;
    final workerCompleter = Completer<void>();

    void checkFinished() {
      if (_completedCount == total || (_isCancelled && activeWorkers == 0)) {
        if (!workerCompleter.isCompleted) {
          workerCompleter.complete();
        }
      }
    }

    Future<void> launchNextWorker() async {
      while (!_isCancelled && nextIndex < total) {
        final currentIndex = nextIndex++;
        final path = _paths[currentIndex];
        activeWorkers++;

        _emit(
          ProcessingEvent(
            stage: ProcessingStage.processing,
            itemPath: path,
            itemIndex: currentIndex,
            completedCount: _completedCount,
            totalCount: total,
            progressFraction: _completedCount / total,
          ),
        );

        BatchItemResult<ProcessedMedia> outcome;
        try {
          if (_isCancelled) {
            outcome = BatchItemResult.failure(
              inputPath: path,
              index: currentIndex,
              error: const MediaForgeException(
                code: MediaForgeErrorCode.cancelled,
                message: 'Batch processing was cancelled',
              ),
            );
          } else {
            final file = File(path);
            if (!await file.exists()) {
              outcome = BatchItemResult.failure(
                inputPath: path,
                index: currentIndex,
                error: MediaForgeException(
                  code: MediaForgeErrorCode.fileNotFound,
                  message: 'File does not exist at path: $path',
                ),
              );
            } else {
              final processed = await MediaProcessor.processImage(
                path,
                options: options,
              );
              outcome = BatchItemResult.success(
                inputPath: path,
                index: currentIndex,
                data: processed,
              );
            }
          }
        } catch (e) {
          final error = e is MediaForgeException
              ? e
              : MediaForgeException(
                  code: MediaForgeErrorCode.processingFailed,
                  message: e.toString(),
                );
          outcome = BatchItemResult.failure(
            inputPath: path,
            index: currentIndex,
            error: error,
          );
        }

        itemResults[currentIndex] = outcome;
        _completedCount++;
        activeWorkers--;

        _emit(
          ProcessingEvent(
            stage: outcome.isSuccess
                ? ProcessingStage.completed
                : (_isCancelled && outcome.error?.code == MediaForgeErrorCode.cancelled
                    ? ProcessingStage.cancelled
                    : ProcessingStage.failed),
            itemPath: path,
            itemIndex: currentIndex,
            completedCount: _completedCount,
            totalCount: total,
            progressFraction: _completedCount / total,
            error: outcome.error,
            result: outcome.data,
          ),
        );
      }

      checkFinished();
    }

    // Launch worker pool up to bounded concurrency
    final poolSize = _concurrency.clamp(1, total);
    for (int i = 0; i < poolSize; i++) {
      unawaited(launchNextWorker());
    }

    await workerCompleter.future;

    // Fill any skipped items if cancelled
    for (int i = 0; i < total; i++) {
      if (itemResults[i] == null) {
        itemResults[i] = BatchItemResult.failure(
          inputPath: _paths[i],
          index: i,
          error: const MediaForgeException(
            code: MediaForgeErrorCode.cancelled,
            message: 'Batch processing was cancelled before processing started',
          ),
        );
        _emit(
          ProcessingEvent(
            stage: ProcessingStage.cancelled,
            itemPath: _paths[i],
            itemIndex: i,
            completedCount: _completedCount,
            totalCount: total,
            progressFraction: _completedCount / total,
          ),
        );
      }
    }

    final finalResult = BatchResult<ProcessedMedia>(
      items: itemResults.whereType<BatchItemResult<ProcessedMedia>>().toList(),
      isCancelled: _isCancelled,
    );

    if (!_completer.isCompleted) {
      _completer.complete(finalResult);
    }
    await _eventsController.close();
  }

  void _emit(ProcessingEvent event) {
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }
}
