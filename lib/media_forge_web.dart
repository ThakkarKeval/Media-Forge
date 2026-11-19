import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'media_forge_platform_interface.dart';

/// A web implementation of the MediaForgePlatform of the MediaForge plugin.
class MediaForgeWeb extends MediaForgePlatform {
  /// Constructs a MediaForgeWeb
  MediaForgeWeb();

  static void registerWith(Registrar registrar) {
    MediaForgePlatform.instance = MediaForgeWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }
}
