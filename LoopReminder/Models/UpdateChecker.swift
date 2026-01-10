import AppKit
import Combine
import Foundation
import Sparkle

@MainActor
final class AppUpdater: NSObject, ObservableObject {
    static let shared = AppUpdater()

    private lazy var updaterController: SPUStandardUpdaterController = {
        SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
    }()

    @Published var automaticallyChecksForUpdates: Bool
    let versionDescription: String

    private override init() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        versionDescription = "\(version) (\(build))"
        automaticallyChecksForUpdates = false

        super.init()
        automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ isOn: Bool) {
        automaticallyChecksForUpdates = isOn
        updaterController.updater.automaticallyChecksForUpdates = isOn
        UserDefaults.standard.set(isOn, forKey: "SUEnableAutomaticChecks")
    }
}

extension AppUpdater: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == "SUSparkleErrorDomain",
           nsError.localizedDescription.localizedCaseInsensitiveContains("up to date") {
            // Sparkle already shows the "up to date" dialog.
            return
        }
        let alert = NSAlert()
        alert.messageText = "无法检查更新"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }
}
