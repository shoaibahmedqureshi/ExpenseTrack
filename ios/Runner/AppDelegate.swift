import Flutter
import UIKit
import StoreKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // This project uses Flutter's implicit-engine template (see
  // UIApplicationSceneManifest in Info.plist) — under this template the
  // engine, its FlutterViewController, and `window` are NOT guaranteed to
  // exist yet by the time didFinishLaunchingWithOptions returns, unlike the
  // older non-scene FlutterAppDelegate template. Registering the channel
  // there (via window?.rootViewController) silently attaches to nothing:
  // no crash, no error, just a channel that never receives calls, which is
  // why every invokeMethod from Dart looked like it was failing/doing
  // nothing. didInitializeImplicitFlutterEngine is the actual point the
  // engine (and a working binaryMessenger) is guaranteed to exist.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.outlay.app/subscriptions",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "showManageSubscriptions":
        self?.showManageSubscriptions(result: result)
      case "getSubscriptionStatus":
        let ids = (call.arguments as? [String: Any])?["productIds"] as? [String] ?? []
        self?.getSubscriptionStatus(productIds: ids, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // Uses StoreKit2's native manage-subscriptions sheet, which correctly
  // respects the current App Store environment — showing sandbox
  // subscriptions when running via TestFlight/Xcode, and real ones once the
  // app is live. This is unlike a web URL to apps.apple.com, which only ever
  // shows production data regardless of build environment.
  private func showManageSubscriptions(result: @escaping FlutterResult) {
    guard #available(iOS 15.0, *) else {
      result(false)
      return
    }
    // Don't rely on AppDelegate's `window` property — under the scene
    // lifecycle the active UIWindowScene is looked up from the app's
    // connected scenes instead, which works regardless of whether/when
    // `window` itself ever gets populated.
    guard let scene = UIApplication.shared.connectedScenes
      .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
    else {
      result(false)
      return
    }
    Task {
      do {
        try await AppStore.showManageSubscriptions(in: scene)
        result(true)
      } catch {
        result(false)
      }
    }
  }

  // Reads entitlement state directly from StoreKit2 (Product.subscription.status),
  // rather than relying on the `in_app_purchase` plugin's purchaseStream having
  // replayed a transaction into this specific app session. This is the
  // authoritative check that makes "is this account actually subscribed" work
  // reliably even in sandbox and after a fresh app launch/reinstall, where the
  // plugin's own event-driven flow can miss a restore.
  private func getSubscriptionStatus(productIds: [String], result: @escaping FlutterResult) {
    guard #available(iOS 15.0, *) else {
      result(nil)
      return
    }
    Task {
      do {
        let products = try await Product.products(for: productIds)
        for product in products {
          guard let subscription = product.subscription else { continue }
          let statuses = try await subscription.status
          for status in statuses {
            guard case .verified(let renewalInfo) = status.renewalInfo,
                  case .verified(let transaction) = status.transaction,
                  status.state == .subscribed || status.state == .inGracePeriod
            else { continue }

            let expirationMillis = transaction.expirationDate.map { $0.timeIntervalSince1970 * 1000 }
            // autoRenewPreference is the product that will actually be
            // billed at the *next* renewal — this differs from
            // transaction.productID exactly when a downgrade/crossgrade is
            // pending (e.g. Annual active now, switched to Monthly, which
            // Apple always defers to the next renewal rather than applying
            // mid-cycle or refunding the unused portion already paid for).
            // Without this, a pending switch is invisible: the app would
            // keep showing the current plan as if nothing had happened.
            result([
              "productId": transaction.productID,
              "willAutoRenew": renewalInfo.willAutoRenew,
              "expirationDateMillis": expirationMillis as Any,
              "autoRenewProductId": renewalInfo.autoRenewPreference as Any,
            ])
            return
          }
        }
        result(nil)
      } catch {
        result(nil)
      }
    }
  }
}
