import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'media_forge_pigeon.dart';

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

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
