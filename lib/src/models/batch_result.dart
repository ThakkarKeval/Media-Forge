import '../errors/media_forge_exception.dart';
import 'processed_media.dart';

/// The current lifecycle stage of an item during batch processing.
enum ProcessingStage {
  /// The item is waiting in the queue.
  queued,

  /// The item is actively being processed.
  processing,

  /// The item was processed successfully.
  completed,

  /// An error occurred while processing the item.
  failed,

  /// Processing was cancelled before or during execution.
  cancelled,
}

/// An honest, measurable progress event emitted during batch processing.
class ProcessingEvent {
  /// Constructs a [ProcessingEvent].
  const ProcessingEvent({
    required this.stage,
    required this.itemPath,
    required this.itemIndex,
    required this.completedCount,
    required this.totalCount,
    this.progressFraction,
    this.error,
    this.result,
  });

  /// The stage transition represented by this event.
  final ProcessingStage stage;

  /// The source input path for the item.
  final String itemPath;

  /// 0-based index of the item in the input batch.
  final int itemIndex;

  /// Number of items completed (either succeeded or failed) so far.
  final int completedCount;

  /// Total number of items in the batch job.
  final int totalCount;

  /// Fraction completed between 0.0 and 1.0 based on finished items.
  final double? progressFraction;

  /// Populated if [stage] is [ProcessingStage.failed].
  final MediaForgeException? error;

  /// Populated if [stage] is [ProcessingStage.completed].
  final ProcessedMedia? result;

  @override
  String toString() =>
      'ProcessingEvent(${stage.name}, item: $itemIndex/$totalCount, progress: ${progressFraction != null ? (progressFraction! * 100).toStringAsFixed(0) : "indet"}%)';
}

/// The individual outcome of processing a single item in a batch.
class BatchItemResult<T> {
  /// Constructs a successful [BatchItemResult].
  const BatchItemResult.success({
    required this.inputPath,
    required this.index,
    required this.data,
  })  : isSuccess = true,
        error = null;

  /// Constructs a failed [BatchItemResult].
  const BatchItemResult.failure({
    required this.inputPath,
    required this.index,
    required this.error,
  })  : isSuccess = false,
        data = null;

  /// The source input path for the item.
  final String inputPath;

  /// 0-based index of the item in the original input list.
  final int index;

  /// Whether processing this specific item succeeded.
  final bool isSuccess;

  /// The successful result data, or `null` if [isSuccess] is false.
  final T? data;

  /// The structured exception, or `null` if [isSuccess] is true.
  final MediaForgeException? error;

  @override
  String toString() => isSuccess
      ? 'BatchItemResult.success(index: $index, path: $inputPath)'
      : 'BatchItemResult.failure(index: $index, path: $inputPath, error: $error)';
}

/// The aggregated outcome of a batch processing operation, preserving input order.
class BatchResult<T> {
  /// Constructs a [BatchResult] from an ordered list of [items].
  const BatchResult({
    required this.items,
    this.isCancelled = false,
  });

  /// All item outcomes in their original input order.
  final List<BatchItemResult<T>> items;

  /// Whether the batch was terminated early by caller cancellation.
  final bool isCancelled;

  /// Total number of items in the batch.
  int get totalCount => items.length;

  /// List of successfully processed results in input order.
  List<T> get successes =>
      items.where((e) => e.isSuccess).map((e) => e.data!).toList();

  /// List of failed item results in input order.
  List<BatchItemResult<T>> get failures =>
      items.where((e) => !e.isSuccess).toList();

  /// Total count of successful items.
  int get successCount => items.where((e) => e.isSuccess).length;

  /// Total count of failed items.
  int get failureCount => items.where((e) => !e.isSuccess).length;

  /// Whether all items in the batch succeeded without failure or cancellation.
  bool get isAllSuccessful => failureCount == 0 && !isCancelled;

  @override
  String toString() =>
      'BatchResult(total: $totalCount, success: $successCount, failed: $failureCount, cancelled: $isCancelled)';
}
