import Cocoa
import FlutterMacOS

public class QuickjsEnginePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "io.quickjs_engine",
      binaryMessenger: registrar.messenger)
    let instance = QuickjsEnginePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // The Dart bridge talks directly to the bundled quickjs-ng via FFI.
    // No method-channel calls are expected at runtime; return notImplemented
    // for any unexpected invocations so the failure mode is loud.
    result(FlutterMethodNotImplemented)
  }
}
