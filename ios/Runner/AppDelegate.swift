import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // CRITICAL: GeneratedPluginRegistrant MUST be called FIRST before any other setup.
    // Calling anything else before this causes EXC_BAD_ACCESS (SIGSEGV) on iOS 26
    // because flutter_local_notifications tries to set UNUserNotificationCenter.delegate
    // before FlutterViewController is fully initialized.
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Explicitly override scene connection to prevent flutter_local_notifications
  // from triggering early UIViewController init on iOS 26 Beta.
  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
  }
}
