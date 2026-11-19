import 'package:flutter_test/flutter_test.dart';
import 'package:media_forge/media_forge.dart';
import 'package:media_forge/media_forge_pigeon.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMediaForgePlatform
    with MockPlatformInterfaceMixin
    implements MediaForgePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<PickedMedia?> pickImage({
    required MediaSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    MediaSelectionOptions? options,
  }) => Future.value(null);

  @override
  Future<PickedMedia?> pickVideo({
    required MediaSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
    MediaSelectionOptions? options,
  }) => Future.value(null);

  @override
  Future<List<PickedMedia>> pickMultiple({
    required MediaType type,
    int? maxItems,
    MediaSelectionOptions? options,
  }) => Future.value(const []);

  @override
  Future<LostDataResponse> retrieveLostData() =>
      Future.value(const LostDataResponse.empty());
}

void main() {
  final initialPlatform = MediaForgePlatform.instance;

  test('PigeonMediaForge is the default instance', () {
    expect(initialPlatform, isInstanceOf<PigeonMediaForge>());
  });

  test('getPlatformVersion', () async {
    MediaForge mediaForgePlugin = const MediaForge();
    MockMediaForgePlatform fakePlatform = MockMediaForgePlatform();
    MediaForgePlatform.instance = fakePlatform;

    expect(await mediaForgePlugin.getPlatformVersion(), '42');
  });
}
