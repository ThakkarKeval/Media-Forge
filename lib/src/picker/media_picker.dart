import '../errors/error_codes.dart';
import '../errors/media_forge_exception.dart';
import '../models/lost_data_response.dart';
import '../models/media_source.dart';
import '../models/media_type.dart';
import '../models/picked_media.dart';
import '../models/selection_options.dart';
import '../platform/media_forge_platform.dart';
import 'picker_validator.dart';

/// Entrypoint for picking and capturing photos and videos.
class MediaPicker {
  const MediaPicker._();

  static MediaForgePlatform get _platform => MediaForgePlatform.instance;
  static const PickerValidator _defaultValidator = PickerValidator();

  /// Picks a single image from the specified [source].
  ///
  /// Returns `null` if the user cancels selection or capture.
  /// Throws [MediaForgeException] if permissions are denied or if the picked
  /// media violates constraints in [options].
  static Future<PickedMedia?> pickImage({
    MediaSource source = MediaSource.gallery,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    MediaSelectionOptions? options,
    PickerValidator validator = _defaultValidator,
  }) async {
    final media = await _platform.pickImage(
      source: source,
      preferredCameraDevice: preferredCameraDevice,
      options: options,
    );
    if (media == null) return null;

    if (options != null) {
      final validation = await validator.validate(media, options);
      if (!validation.isValid) {
        throw MediaForgeException(
          code: MediaForgeErrorCode.validationFailed,
          message:
              'Selected image violated constraints: ${validation.violations.join('; ')}',
          details: validation.violations,
        );
      }
    }

    return media;
  }

  /// Picks a single video from the specified [source].
  ///
  /// Returns `null` if the user cancels selection or capture.
  /// Throws [MediaForgeException] if permissions are denied or if the picked
  /// video violates constraints in [options].
  static Future<PickedMedia?> pickVideo({
    MediaSource source = MediaSource.gallery,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
    MediaSelectionOptions? options,
    PickerValidator validator = _defaultValidator,
  }) async {
    final effectiveOptions =
        options ??
        (maxDuration != null
            ? MediaSelectionOptions(maxDuration: maxDuration)
            : null);

    final media = await _platform.pickVideo(
      source: source,
      preferredCameraDevice: preferredCameraDevice,
      maxDuration: maxDuration,
      options: effectiveOptions,
    );
    if (media == null) return null;

    if (effectiveOptions != null) {
      final validation = await validator.validate(media, effectiveOptions);
      if (!validation.isValid) {
        throw MediaForgeException(
          code: MediaForgeErrorCode.validationFailed,
          message:
              'Selected video violated constraints: ${validation.violations.join('; ')}',
          details: validation.violations,
        );
      }
    }

    return media;
  }

  /// Picks multiple photos, videos, or mixed media from the gallery.
  ///
  /// Enforces [maxItems] natively where supported and validates post-selection.
  /// Returns an empty list if the user cancels.
  /// Throws [MediaForgeException] if permissions are denied or if items violate [options].
  static Future<List<PickedMedia>> pickMultiple({
    MediaType type = MediaType.image,
    int? maxItems,
    MediaSelectionOptions? options,
    PickerValidator validator = _defaultValidator,
  }) async {
    final effectiveOptions =
        options ??
        (maxItems != null ? MediaSelectionOptions(maxItems: maxItems) : null);

    final items = await _platform.pickMultiple(
      type: type,
      maxItems: maxItems,
      options: effectiveOptions,
    );
    if (items.isEmpty) return const [];

    if (effectiveOptions != null) {
      final validation = await validator.validateAll(items, effectiveOptions);
      if (!validation.isValid) {
        throw MediaForgeException(
          code: MediaForgeErrorCode.validationFailed,
          message:
              'Selected media items violated constraints: ${validation.violations.join('; ')}',
          details: validation.violations,
        );
      }
    }

    return items;
  }

  /// Retrieves any pending media or errors recovered from an Android Activity
  /// destroyed and recreated while the native picker or camera was displayed.
  static Future<LostDataResponse> retrieveLostData() {
    return _platform.retrieveLostData();
  }
}
