import 'package:flutter/foundation.dart';

import 'media_forge_platform_interface.dart';
import 'src/messages.g.dart';

/// An implementation of [MediaForgePlatform] that uses Pigeon, for
/// non-web platforms.
class PigeonMediaForge extends MediaForgePlatform {
  /// Creates a new plugin implementation instance.
  PigeonMediaForge({@visibleForTesting MediaForgePluginApi? api})
    : _hostApi = api ?? MediaForgePluginApi();

  final MediaForgePluginApi _hostApi;

  @override
  Future<String?> getPlatformVersion() async {
    return _hostApi.getPlatformVersion();
  }
}
