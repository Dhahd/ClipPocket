import Foundation
import AppKit
import UserNotifications

class UpdateChecker: NSObject, ObservableObject {
    static let shared = UpdateChecker()

    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false
    @Published var latestVersion: String?
    @Published var downloadURL: String?
    @Published var releaseNotes: String?
    @Published var isDownloadingUpdate = false
    @Published var downloadProgress: Double = 0.0

    private var currentVersion: String {
        return AppVersion.current
    }
    private let githubOwner = "Dhahd"
    private let githubRepo = "ClipPocket"
    private var downloadTask: URLSessionDownloadTask?

    private override init() {
        super.init()
    }

    // MARK: - Public Methods

    func checkForUpdates(showAlert: Bool = false) {
        guard !isCheckingForUpdates else { return }

        isCheckingForUpdates = true

        fetchLatestRelease { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isCheckingForUpdates = false

                switch result {
                case .success(let release):
                    self.handleReleaseInfo(release, showAlert: showAlert)
                case .failure(let error):
                    if showAlert {
                        self.showErrorAlert(error)
                    }
                    print("Update check failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func checkForUpdatesOnLaunch() {
        let lastCheckKey = "LastUpdateCheck"
        let checkIntervalKey = "UpdateCheckInterval"

        // Get user preference for check interval (default: 1 day)
        let checkInterval = UserDefaults.standard.double(forKey: checkIntervalKey)
        let interval = checkInterval > 0 ? checkInterval : 86400 // 24 hours

        if let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date {
            let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)

            if timeSinceLastCheck < interval {
                print("⏭️ Skipping update check (last check: \(Int(timeSinceLastCheck/3600))h ago)")
                return
            }
        }

        // Perform check silently
        checkForUpdates(showAlert: false)
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
    }

    // MARK: - Private Methods

    private func fetchLatestRelease(completion: @escaping (Result<GitHubRelease, Error>) -> Void) {
        let urlString = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest"

        print("🔍 Checking for updates at: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            completion(.failure(UpdateError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                if let urlError = error as? URLError {
                    print("   Error code: \(urlError.code.rawValue)")
                }
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(UpdateError.noData))
                return
            }

            // Check for rate limiting
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 403 {
                completion(.failure(UpdateError.rateLimited))
                return
            }

            // Check for 404 (no releases yet or private repo)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 404 {
                print("ℹ️  Note: 404 could mean private repository or no releases")
                completion(.failure(UpdateError.noReleases))
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let release = try decoder.decode(GitHubRelease.self, from: data)
                completion(.success(release))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func handleReleaseInfo(_ release: GitHubRelease, showAlert: Bool) {
        latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
        releaseNotes = release.body

        // Find DMG asset
        if let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
            downloadURL = dmgAsset.browserDownloadUrl
        }

        // Compare versions
        if isNewerVersion(latestVersion ?? "", than: currentVersion) {
            updateAvailable = true

            if showAlert {
                showUpdateAlert()
            } else {
                showUpdateNotification()
            }
        } else if showAlert {
            showNoUpdateAlert()
        }
    }

    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newComponents.count, currentComponents.count) {
            let newPart = i < newComponents.count ? newComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0

            if newPart > currentPart {
                return true
            } else if newPart < currentPart {
                return false
            }
        }

        return false
    }

    private func showUpdateAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Update Available!"
            alert.informativeText = """
            A new version of ClipPocket is available.

            Current version: \(self.currentVersion)
            Latest version: \(self.latestVersion ?? "Unknown")

            \(self.releaseNotes ?? "")

            Would you like to download it now?
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
            alert.addButton(withTitle: "Release Notes")

            let response = alert.runModal()

            switch response {
            case .alertFirstButtonReturn: // Download
                self.downloadAndInstallUpdate()
            case .alertThirdButtonReturn: // Release Notes
                self.openReleasePage()
            default:
                break
            }
        }
    }

    private func showUpdateNotification() {
        DispatchQueue.main.async {
            let content = UNMutableNotificationContent()
            content.title = "ClipPocket Update Available"
            content.body = "Version \(self.latestVersion ?? "Unknown") is now available. Click to download."
            content.sound = .default
            content.userInfo = ["action": "download"]

            let request = UNNotificationRequest(
                identifier: "update-available",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to show update notification: \(error)")
                }
            }
        }
    }

    private func showNoUpdateAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "You're Up to Date!"
            alert.informativeText = "ClipPocket \(self.currentVersion) is the latest version."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private func showErrorAlert(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Update Check Failed"

            if let updateError = error as? UpdateError {
                alert.informativeText = updateError.userMessage
            } else if let urlError = error as? URLError {
                // More detailed URL error messages
                switch urlError.code {
                case .notConnectedToInternet:
                    alert.informativeText = "No internet connection. Please check your network and try again."
                case .cannotFindHost:
                    alert.informativeText = "Cannot reach GitHub servers. This might mean:\n\n• No internet connection\n• GitHub repository doesn't exist yet\n• Firewall blocking access\n\nTip: Make sure you've created the GitHub repository at:\ngithub.com/\(self.githubOwner)/\(self.githubRepo)"
                case .timedOut:
                    alert.informativeText = "Request timed out. Please check your internet connection and try again."
                default:
                    alert.informativeText = "Network error: \(urlError.localizedDescription)"
                }
            } else {
                alert.informativeText = "Could not check for updates: \(error.localizedDescription)"
            }

            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")

            // Add "View Repository" button if it's a host not found error
            if let urlError = error as? URLError, urlError.code == .cannotFindHost {
                alert.addButton(withTitle: "View Repository on GitHub")
            }

            let response = alert.runModal()

            // Open GitHub repo if user clicked the button
            if response == .alertSecondButtonReturn {
                let repoURL = URL(string: "https://github.com/\(self.githubOwner)/\(self.githubRepo)")!
                NSWorkspace.shared.open(repoURL)
            }
        }
    }

    private func downloadAndInstallUpdate() {
        guard let urlString = downloadURL,
              let url = URL(string: urlString) else {
            showDownloadError("Invalid download URL")
            return
        }

        isDownloadingUpdate = true
        downloadProgress = 0.0

        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)

        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()

        // Show progress alert
        showDownloadProgressAlert()
    }

    private func showDownloadProgressAlert() {
        // Don't show modal dialog - just show a notification instead
        // Modal dialogs during downloads are problematic
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = "Downloading Update"
            notification.informativeText = "Downloading ClipPocket \(self.latestVersion ?? "")..."
            notification.soundName = nil
            NSUserNotificationCenter.default.deliver(notification)
        }
    }

    private func installDMG(at fileURL: URL) {
        DispatchQueue.main.async {
            self.isDownloadingUpdate = false

            let alert = NSAlert()
            alert.messageText = "Update Downloaded!"
            alert.informativeText = """
            ClipPocket \(self.latestVersion ?? "") has been downloaded successfully.

            Click "Install" to open the installer. You'll need to:
            1. Drag the new version to Applications (replacing the old one)
            2. Restart ClipPocket

            The installer will open automatically.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Install Now")
            alert.addButton(withTitle: "Install Later")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                // Open the DMG file
                NSWorkspace.shared.open(fileURL)

                // Show instructions
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let instructionsAlert = NSAlert()
                    instructionsAlert.messageText = "Installation Instructions"
                    instructionsAlert.informativeText = """
                    The installer has been opened.

                    To complete the update:
                    1. Drag ClipPocket to the Applications folder
                    2. Replace the existing version when prompted
                    3. Quit this app and launch the new version

                    Would you like to quit ClipPocket now?
                    """
                    instructionsAlert.alertStyle = .informational
                    instructionsAlert.addButton(withTitle: "Quit ClipPocket")
                    instructionsAlert.addButton(withTitle: "I'll Do It Later")

                    let quitResponse = instructionsAlert.runModal()
                    if quitResponse == .alertFirstButtonReturn {
                        NSApplication.shared.terminate(nil)
                    }
                }
            } else {
                // Save DMG location for later
                let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                if let downloadsFolder = downloadsFolder {
                    let destinationURL = downloadsFolder.appendingPathComponent(fileURL.lastPathComponent)
                    try? FileManager.default.moveItem(at: fileURL, to: destinationURL)

                    let laterAlert = NSAlert()
                    laterAlert.messageText = "Update Saved"
                    laterAlert.informativeText = "The installer has been saved to your Downloads folder:\n\n\(fileURL.lastPathComponent)\n\nYou can install it whenever you're ready."
                    laterAlert.alertStyle = .informational
                    laterAlert.addButton(withTitle: "OK")
                    laterAlert.runModal()
                }
            }
        }
    }

    private func showDownloadError(_ message: String) {
        DispatchQueue.main.async {
            self.isDownloadingUpdate = false

            let alert = NSAlert()
            alert.messageText = "Download Failed"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Download Manually")

            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                self.openDownloadPage()
            }
        }
    }

    private func openDownloadPage() {
        if let urlString = downloadURL,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            openReleasePage()
        }
    }

    private func openReleasePage() {
        let urlString = "https://github.com/\(githubOwner)/\(githubRepo)/releases/latest"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - URLSession Download Delegate

extension UpdateChecker: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move downloaded file to temporary location with proper name
        let tempDir = FileManager.default.temporaryDirectory
        let destinationURL = tempDir.appendingPathComponent("ClipPocket-Update.dmg")

        // Remove old file if exists
        try? FileManager.default.removeItem(at: destinationURL)

        do {
            try FileManager.default.moveItem(at: location, to: destinationURL)
            installDMG(at: destinationURL)
        } catch {
            showDownloadError("Failed to save update: \(error.localizedDescription)")
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.downloadProgress = progress
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            showDownloadError(error.localizedDescription)
        }
    }
}

// MARK: - Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let assets: [GitHubAsset]
    let publishedAt: String
    let prerelease: Bool
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
    let downloadCount: Int
}

// MARK: - Errors

enum UpdateError: LocalizedError {
    case invalidURL
    case noData
    case noReleases
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub URL"
        case .noData:
            return "No data received from GitHub"
        case .noReleases:
            return "No releases found"
        case .rateLimited:
            return "GitHub API rate limit exceeded"
        }
    }

    var userMessage: String {
        switch self {
        case .invalidURL:
            return "There was a problem checking for updates. Please try again later."
        case .noData:
            return "Could not retrieve update information. Please check your internet connection."
        case .noReleases:
            return "Unable to check for updates at this time.\n\nThis could mean:\n• You're using a development or pre-release version\n• Update service is temporarily unavailable\n\nCheck back later or visit the website for the latest version."
        case .rateLimited:
            return "Too many update checks. Please try again in an hour."
        }
    }
}

// MARK: - Notification Handling

// Note: To handle notification taps, implement UNUserNotificationCenterDelegate
// in AppDelegate and check for notification.request.identifier == "update-available"
