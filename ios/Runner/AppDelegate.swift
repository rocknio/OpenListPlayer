import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 提供编译期可靠的模拟器检测（Dart 的 Platform.environment 在 iOS 恒为空；
    // UIScene 架构下 window 归属 SceneDelegate，必须通过 engineBridge 注册通道）
    let channel = FlutterMethodChannel(
      name: "olp/device",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSimulator":
        #if targetEnvironment(simulator)
        result(true)
        #else
        result(false)
        #endif
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
