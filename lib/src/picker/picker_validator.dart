import 'dart:io';

import '../models/picked_media.dart';
import '../models/selection_options.dart';
import '../models/validation_result.dart';

/// Validates [PickedMedia] items against caller-specified [MediaSelectionOptions].
class PickerValidator {
  const PickerValidator();

  /// Validates a single [media] item against [options].
  Future<ValidationResult> validate(
    PickedMedia media,
    MediaSelectionOptions options,
  ) async {
    final violations = <String>[];

    // File size validation
    if (options.maxSizeBytes != null) {
      int? size = media.sizeBytes;
      if (size == null) {
        final file = File(media.path);
        if (await file.exists()) {
          size = await file.length();
        }
      }
      if (size != null && size > options.maxSizeBytes!) {
        violations.add(
          'File size ($size bytes) exceeds maximum allowed size of ${options.maxSizeBytes} bytes',
        );
      }
    }

    // Dimensions validation
    if (options.maxWidth != null &&
        media.width != null &&
        media.width! > options.maxWidth!) {
      violations.add(
        'Width (${media.width}px) exceeds maximum allowed width of ${options.maxWidth}px',
      );
    }
    if (options.maxHeight != null &&
        media.height != null &&
        media.height! > options.maxHeight!) {
      violations.add(
        'Height (${media.height}px) exceeds maximum allowed height of ${options.maxHeight}px',
      );
    }

    // Video duration validation
    if (options.maxDuration != null &&
        media.duration != null &&
        media.duration! > options.maxDuration!) {
      violations.add(
        'Duration (${media.duration!.inSeconds}s) exceeds maximum allowed duration of ${options.maxDuration!.inSeconds}s',
      );
    }

    // MIME type validation
    if (options.allowedMimeTypes != null &&
        options.allowedMimeTypes!.isNotEmpty) {
      final mime = media.mimeType?.toLowerCase();
      if (mime != null) {
        final allowed = options.allowedMimeTypes!
            .map((e) => e.toLowerCase().trim())
            .toList();
        final matches = allowed.any((pattern) {
          if (pattern.endsWith('/*')) {
            final prefix = pattern.substring(0, pattern.length - 1);
            return mime.startsWith(prefix);
          }
          return pattern == mime;
        });
        if (!matches) {
          violations.add(
            'MIME type "$mime" is not in allowed types: ${options.allowedMimeTypes!.join(', ')}',
          );
        }
      }
    }

    if (violations.isEmpty) {
      return const ValidationResult.valid();
    }
    return ValidationResult.invalid(violations);
  }

  /// Validates a list of [mediaList] items against [options], including count checks.
  Future<ValidationResult> validateAll(
    List<PickedMedia> mediaList,
    MediaSelectionOptions options,
  ) async {
    final violations = <String>[];

    if (options.maxItems != null && mediaList.length > options.maxItems!) {
      violations.add(
        'Selected ${mediaList.length} items, but maximum allowed count is ${options.maxItems}',
      );
    }

    for (var i = 0; i < mediaList.length; i++) {
      final itemResult = await validate(mediaList[i], options);
      if (!itemResult.isValid) {
        for (final v in itemResult.violations) {
          violations.add('Item [${i + 1}]: $v');
        }
      }
    }

    if (violations.isEmpty) {
      return const ValidationResult.valid();
    }
    return ValidationResult.invalid(violations);
  }
}
