import Flutter
import UIKit

public class MediaForgePlugin: NSObject, FlutterPlugin, MediaForgePluginApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MediaForgePlugin()
    MediaForgePluginApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)

    let picker = MediaForgePicker()
    MediaForgePickerApiSetup.setUp(binaryMessenger: registrar.messenger(), api: picker)

    let processor = MediaForgeProcessor()
    MediaForgeProcessorApiSetup.setUp(binaryMessenger: registrar.messenger(), api: processor)
  }

  public func getPlatformVersion() throws -> String {
    return "iOS " + UIDevice.current.systemVersion
  }
}
