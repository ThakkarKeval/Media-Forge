import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_forge/media_forge_pigeon.dart';
import 'package:media_forge/src/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getPlatformVersion', () async {
    final api = FakeMediaForgePluginApi(platformVersion: '42');
    final plugin = PigeonMediaForge(api: api);

    expect(await plugin.getPlatformVersion(), '42');
  });
}

/// Fake implementation of the Pigeon API that provides a pre-set response.
class FakeMediaForgePluginApi implements MediaForgePluginApi {
  FakeMediaForgePluginApi({required this.platformVersion});

  final String platformVersion;

  @override
  Future<String> getPlatformVersion() async {
    return platformVersion;
  }

  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;

  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';
}
