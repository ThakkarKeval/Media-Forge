import '../errors/media_forge_exception.dart';
import 'picked_media.dart';

/// Response containing media or errors recovered after the Android host Activity
/// was destroyed and recreated during an active picker or camera session.
class LostDataResponse {
  /// Constructs a [LostDataResponse].
  const LostDataResponse({this.items = const [], this.exception});

  /// Constructs an empty response indicating no lost data was pending.
  const LostDataResponse.empty() : items = const [], exception = null;

  /// Recovered media items that were picked or captured before Activity recreation.
  final List<PickedMedia> items;

  /// Exception recorded if the interrupted session encountered an error.
  final MediaForgeException? exception;

  /// Whether any items or errors were recovered.
  bool get isEmpty => items.isEmpty && exception == null;

  /// Whether items were successfully recovered.
  bool get isNotEmpty => !isEmpty;

  @override
  String toString() =>
      'LostDataResponse(items: ${items.length}, exception: $exception)';
}
