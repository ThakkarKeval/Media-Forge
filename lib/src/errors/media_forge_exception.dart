import 'error_codes.dart';

/// Exception thrown by MediaForge operations when an error occurs.
class MediaForgeException implements Exception {
  /// Constructs a [MediaForgeException] with a structured [code], descriptive
  /// [message], and optional [details].
  const MediaForgeException({
    required this.code,
    required this.message,
    this.details,
  });

  /// Stable error taxonomy code.
  final MediaForgeErrorCode code;

  /// Human-readable explanation of the error.
  final String message;

  /// Optional underlying native or platform details.
  final dynamic details;

  @override
  String toString() {
    if (details != null) {
      return 'MediaForgeException(${code.name}): $message (details: $details)';
    }
    return 'MediaForgeException(${code.name}): $message';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaForgeException &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => code.hashCode ^ message.hashCode;
}
