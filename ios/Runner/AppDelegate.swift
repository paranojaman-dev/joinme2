import Flutter
import UIKit
import GoogleMaps

GMSServices.provideAPIKey("AIzaSyAT3ZtEDonPiYK6RPcwb4XmP0wUEW3H3yY")
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
