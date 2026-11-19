import 'package:pigeon/pigeon.dart';

// This file is where you define the interface between Dart code and host
// platform code. After editing this file, run
//   dart run pigeon --input pigeon/messages.dart
// to re-generate all of the output files.
//
// If you add new platforms to your plugin, add the corresponding output
// options in the PigeonOptions below.
//
// To learn more about Pigeon, see https://pub.dev/packages/pigeon.

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'media_forge',
    dartOut: 'lib/src/messages.g.dart',
    cppHeaderOut: 'windows/messages.g.h',
    cppSourceOut: 'windows/messages.g.cpp',
    cppOptions: CppOptions(namespace: 'media_forge'),
    gobjectHeaderOut: 'linux/messages.g.h',
    gobjectSourceOut: 'linux/messages.g.cc',
    kotlinOut: 'android/src/main/kotlin/com/cavernlabs/media/forge/media_forge/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.cavernlabs.media.forge.media_forge',
    ),
    swiftOut: [
      'ios/media_forge/Sources/media_forge/Messages.g.swift',
      'macos/media_forge/Sources/media_forge/Messages.g.swift',
    ],
  ),
)
@HostApi()
abstract class MediaForgePluginApi {
  /// Returns the system version of the host platform.
  String getPlatformVersion();
}
