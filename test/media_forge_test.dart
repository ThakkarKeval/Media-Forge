import 'package:flutter_test/flutter_test.dart';
import 'package:media_forge/media_forge.dart';
import 'package:media_forge/media_forge_pigeon.dart';
import 'package:media_forge/media_forge_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaForgePlatform
    with MockPlatformInterfaceMixin
    implements MediaForgePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final initialPlatform = MediaForgePlatform.instance;

  test('PigeonMediaForge is the default instance', () {
    expect(initialPlatform, isInstanceOf<PigeonMediaForge>());
  });

  test('getPlatformVersion', () async {
    MediaForge mediaForgePlugin = MediaForge();
    MockMediaForgePlatform fakePlatform = MockMediaForgePlatform();
    MediaForgePlatform.instance = fakePlatform;

    expect(await mediaForgePlugin.getPlatformVersion(), '42');
  });
}
