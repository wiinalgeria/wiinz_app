import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase HERE, natively, from GoogleService-Info.plist.
    //
    // It used to be configured from Dart (core/firebase_ios.dart), because the
    // .plist could not be added to the Xcode target from Windows. That worked
    // for everything except the one thing that mattered: FirebaseApp installs
    // its UIApplicationDelegate swizzling at configure() time, and configuring
    // from Dart happens AFTER this method returns — so the
    // didRegisterForRemoteNotificationsWithDeviceToken callback could fire with
    // nothing listening. Symptom: getAPNSToken() returning null forever on a
    // correctly-signed build with authorization already granted.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }

    // Ask APNs for a device token explicitly rather than relying on a plugin to
    // do it. Safe before the user has granted notification permission: the APNs
    // token is about connectivity to Apple, not about authorization.
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Hand the APNs token to Firebase directly. With swizzling working this is
  // redundant but harmless; if swizzling is late, disabled, or defeated by the
  // UIScene lifecycle, it is the only thing that gets the token across.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    UserDefaults.standard.set("granted (\(deviceToken.count) bytes)", forKey: "flutter.apns_status")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // If Apple refuses, record WHY. Without this the failure is invisible: iOS
  // tells the user nothing and the app simply never receives a token. The
  // "flutter." prefix is the one shared_preferences uses, so the diagnostics
  // sheet can read this straight back out of UserDefaults.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    UserDefaults.standard.set("FAILED: \(error.localizedDescription)", forKey: "flutter.apns_status")
    NSLog("[WIIN] APNs registration failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
