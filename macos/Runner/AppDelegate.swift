import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    // Set up channel so Dart can retrieve a cold-start shared file path
    // via popPendingFile (stored in UserDefaults by application(_:openFile:)).
    guard let window = mainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "cn.zhuhkblog.billbuddy/share",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "popPendingFile" {
        let path = UserDefaults.standard.string(forKey: "pendingImportFile")
        if path != nil { UserDefaults.standard.removeObject(forKey: "pendingImportFile") }
        result(path)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Handle .xlsx files opened with "Open With" on macOS.
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    saveAndForward(filename)
    return true
  }

  /// Save the file path in UserDefaults and forward to Dart if engine is ready.
  private func saveAndForward(_ path: String) {
    UserDefaults.standard.set(path, forKey: "pendingImportFile")

    guard let window = mainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "cn.zhuhkblog.billbuddy/share",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.invokeMethod("onFileShared", arguments: path)
    UserDefaults.standard.removeObject(forKey: "pendingImportFile")
  }
}
