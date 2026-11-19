export 'media_forge_platform_interface.dart';
export 'src/errors/error_codes.dart';
export 'src/errors/media_forge_exception.dart';
export 'src/models/lost_data_response.dart';
export 'src/models/media_source.dart';
export 'src/models/media_type.dart';
export 'src/models/picked_media.dart';
export 'src/models/selection_options.dart';
export 'src/models/validation_result.dart';
export 'src/picker/media_picker.dart';
export 'src/picker/picker_validator.dart';

import 'media_forge_platform_interface.dart';
import 'src/models/lost_data_response.dart';
import 'src/models/media_source.dart';
import 'src/models/media_type.dart';
import 'src/models/picked_media.dart';
import 'src/models/selection_options.dart';
import 'src/picker/media_picker.dart';
import 'src/picker/picker_validator.dart';

/// Top-level facade providing convenient access to picking and processing media.
class MediaForge {
  /// Constructs a [MediaForge] instance.
  const MediaForge();

  /// Picks a single photo from the specified [source].
  static Future<PickedMedia?> pickImage({
    MediaSource source = MediaSource.gallery,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    MediaSelectionOptions? options,
    PickerValidator validator = const PickerValidator(),
  }) {
    return MediaPicker.pickImage(
      source: source,
      preferredCameraDevice: preferredCameraDevice,
      options: options,
      validator: validator,
    );
  }

  /// Picks a single video from the specified [source].
  static Future<PickedMedia?> pickVideo({
    MediaSource source = MediaSource.gallery,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
    MediaSelectionOptions? options,
    PickerValidator validator = const PickerValidator(),
  }) {
    return MediaPicker.pickVideo(
      source: source,
      preferredCameraDevice: preferredCameraDevice,
      maxDuration: maxDuration,
      options: options,
      validator: validator,
    );
  }

  /// Picks multiple photos, videos, or mixed media from the gallery.
  static Future<List<PickedMedia>> pickMultiple({
    MediaType type = MediaType.image,
    int? maxItems,
    MediaSelectionOptions? options,
    PickerValidator validator = const PickerValidator(),
  }) {
    return MediaPicker.pickMultiple(
      type: type,
      maxItems: maxItems,
      options: options,
      validator: validator,
    );
  }

  /// Retrieves any pending media recovered after Android Activity recreation.
  static Future<LostDataResponse> retrieveLostData() {
    return MediaPicker.retrieveLostData();
  }

  /// Returns the current platform version string.
  Future<String?> getPlatformVersion() {
    return MediaForgePlatform.instance.getPlatformVersion();
  }
}
