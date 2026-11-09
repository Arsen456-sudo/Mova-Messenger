import UIKit
import MessengerShared

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: RegistrationViewController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        Task { @MainActor in
            do {
                try await AppServices.repository.handleDeepLink(url: url.absoluteString)
                window?.rootViewController = UINavigationController(rootViewController: ConversationsViewController())
            } catch {
                let alert = UIAlertController(title: "Не вдалося підтвердити email", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Добре", style: .default))
                window?.rootViewController?.present(alert, animated: true)
            }
        }
        return true
    }
}
