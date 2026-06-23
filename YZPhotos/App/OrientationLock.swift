import UIKit

/// Verrouillage d'orientation : l'**iPad** tourne toujours librement ;
/// l'**iPhone** est en **portrait** par défaut, sauf si l'utilisateur autorise
/// le paysage (réglage `allowLandscapeIPhone`).
enum OrientationLock {
    static var mask: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad { return .all }
        return UserDefaults.standard.bool(forKey: AppSettings.allowLandscapeIPhoneKey)
            ? .allButUpsideDown : .portrait
    }

    /// Force iOS à réévaluer l'orientation supportée après un changement de réglage.
    @MainActor static func apply() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

/// AppDelegate minimal : fournit le masque d'orientation à iOS.
final class YZAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}
