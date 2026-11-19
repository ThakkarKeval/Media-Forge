import 'media_forge_platform_interface.dart';

/// The main interface for the MediaForge plugin.
class MediaForge {
  /// Returns the system version of the current platform.
  Future<String?> getPlatformVersion() {
    return MediaForgePlatform.instance.getPlatformVersion();
  }
}
