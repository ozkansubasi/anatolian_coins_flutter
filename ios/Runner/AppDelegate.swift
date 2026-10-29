import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterPluginRegistrant {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps SDK anahtar verilmeden kullanılırsa uygulamayı durdurur (sikke detayındaki harita, iOS-03).
    // Anahtar git dışı ios/Flutter/Secrets.xcconfig → Info.plist GMSApiKey (android/key.properties düzeni).
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.isEmpty, !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
    } else {
      NSLog("[NumisTR] GMSApiKey yok: ios/Flutter/Secrets.xcconfig eksik, harita açılamaz")
    }
    // Sahne düzeninde (Info.plist UIApplicationSceneManifest) AppDelegate'in penceresi yok; eklentiler
    // Main.storyboard'dan gelen FlutterViewController'ın motoruna register(with:) üzerinden kaydedilir.
    pluginRegistrant = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
  }
}
