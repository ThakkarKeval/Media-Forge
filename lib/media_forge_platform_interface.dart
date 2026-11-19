import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'media_forge_pigeon.dart';
import 'src/models/image_options.dart';
import 'src/models/lost_data_response.dart';
import 'src/models/media_source.dart';
import 'src/models/media_type.dart';
import 'src/models/picked_media.dart';
import 'src/models/processed_media.dart';
import 'src/models/selection_options.dart';

/// The common platform interface for the MediaForge plugin.
abstract class MediaForgePlatform extends PlatformInterface {
  /// Constructs a MediaForgePlatform.
  MediaForgePlatform() : super(token: _token);

  static final Object _token = Object();

  static MediaForgePlatform _instance = PigeonMediaForge();

  /// The instance of [MediaForgePlatform] to use.
  ///
  /// Defaults to [PigeonMediaForge].
  static MediaForgePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MediaForgePlatform] when
  /// they register themselves.
  static set instance(MediaForgePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the platform version string.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Picks a single image from [source].
  Future<PickedMedia?> pickImage({
    required MediaSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    MediaSelectionOptions? options,
  }) {
    throw UnimplementedError('pickImage() has not been implemented.');
  }

  /// Picks a single video from [source].
  Future<PickedMedia?> pickVideo({
    required MediaSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
    MediaSelectionOptions? options,
  }) {
    throw UnimplementedError('pickVideo() has not been implemented.');
  }

  /// Picks multiple items of [type] from the gallery.
  Future<List<PickedMedia>> pickMultiple({
    required MediaType type,
    int? maxItems,
    MediaSelectionOptions? options,
  }) {
    throw UnimplementedError('pickMultiple() has not been implemented.');
  }

  /// Retrieves lost data after Android Activity recreation.
  Future<LostDataResponse> retrieveLostData() {
    throw UnimplementedError('retrieveLostData() has not been implemented.');
  }

  /// Processes and optimizes a local image file with [options].
  Future<ProcessedMedia> processImage({
    required String path,
    required ImageProcessingOptions options,
  }) {
    throw UnimplementedError('processImage() has not been implemented.');
  }

  /// Clears managed temporary intermediate output files.
  Future<bool> clearCache() {
    throw UnimplementedError('clearCache() has not been implemented.');
  }
}
