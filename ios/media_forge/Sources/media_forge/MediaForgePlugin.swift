import Flutter
import UIKit

public class MediaForgePlugin: NSObject, FlutterPlugin, MediaForgePluginApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = MediaForgePlugin()
    MediaForgePluginApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  public func getPlatformVersion() throws -> String {
    return "iOS " + UIDevice.current.systemVersion
  }
}
