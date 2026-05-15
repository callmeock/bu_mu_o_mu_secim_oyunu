import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase Messaging için APNS token kaydet
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // APNS token alındığında Firebase'e kaydet
  override func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    print("✅ APNS Token Firebase'e kaydedildi")
  }
  
  // APNS token alınamadığında (ör: simulator)
  override func application(_ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("⚠️ APNS Token alınamadı: \(error.localizedDescription)")
    print("ℹ️ Not: iOS Simulator'da push notification desteklenmez. Gerçek cihazda test edin.")
  }
}
