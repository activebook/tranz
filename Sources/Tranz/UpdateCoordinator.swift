import AppKit
import Combine
import CryptoKit
import Foundation

/// Represents the discrete states of the application update lifecycle.
enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case updateAvailable(version: String, releaseNotes: String, htmlURL: URL, downloadURL: URL, sha256URL: URL?, sizeBytes: Int64)
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case verifying
    case readyToRestart(stagedAppURL: URL, targetAppURL: URL)
    case failed(error: String)

    static func == (lhs: UpdateState, rhs: UpdateState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.verifying, .verifying):
            return true
        case let (.upToDate(a), .upToDate(b)):
            return a == b
        case let (.updateAvailable(v1, _, _, _, _, _), .updateAvailable(v2, _, _, _, _, _)):
            return v1 == v2
        case let (.downloading(p1, w1, t1), .downloading(p2, w2, t2)):
            return p1 == p2 && w1 == w2 && t1 == t2
        case let (.readyToRestart(s1, t1), .readyToRestart(s2, t2)):
            return s1 == s2 && t1 == t2
        case let (.failed(e1), .failed(e2)):
            return e1 == e2
        default:
            return false
        }
    }
}

// MARK: - GitHub API Decodable Models

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }
}

struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadUrl: String
    let size: Int64

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

// MARK: - Update Coordinator

/// Coordinates update checking, cryptographic verification, asset staging, and atomic in-place app bundle updates.
final class UpdateCoordinator: NSObject, ObservableObject {
    static let shared = UpdateCoordinator()

    @Published private(set) var state: UpdateState = .idle
    @Published private(set) var lastCheckedDate: Date?

    private var activeDownloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var stagedDirectoryURL: URL?
    private var currentExpectedSHA256: String?
    private var currentReleaseInfo: (version: String, downloadURL: URL, sha256URL: URL?, size: Int64)?

    private let repoOwner = "activebook"
    private let repoName = "tranz"

    /// The installed application version extracted from Info.plist.
    var currentVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// The installed application build version.
    var currentBuildVersionString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private override init() {
        super.init()
    }

    // MARK: - Public Actions

    /// Checks GitHub Releases for a newer version than the running build.
    func checkForUpdates(isUserInitiated: Bool = false) {
        if state == .checking { return }
        if case .downloading = state { return }
        if case .verifying = state { return }
        if case .readyToRestart = state { return }

        DispatchQueue.main.async {
            self.state = .checking
            self.lastCheckedDate = Date()
        }

        guard let apiURL = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            DispatchQueue.main.async {
                self.state = .failed(error: "Malformed GitHub API endpoint.")
            }
            return
        }

        var request = URLRequest(url: apiURL)
        request.setValue("Tranz-App/\(currentVersionString)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.state = .failed(error: "Network error: \(error.localizedDescription)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.state = .failed(error: "Invalid HTTP response.")
                }
                return
            }

            guard httpResponse.statusCode == 200, let data = data else {
                DispatchQueue.main.async {
                    if httpResponse.statusCode == 404 {
                        self.state = .upToDate(currentVersion: self.currentVersionString)
                    } else {
                        self.state = .failed(error: "GitHub API returned status \(httpResponse.statusCode).")
                    }
                }
                return
            }

            do {
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                self.processRelease(release)
            } catch {
                DispatchQueue.main.async {
                    self.state = .failed(error: "Failed to parse release metadata: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    /// Downloads the latest release archive and prepares the upgrade.
    func downloadAndPrepareUpdate() {
        guard case let .updateAvailable(version, _, _, downloadURL, sha256URL, size) = state else { return }

        currentReleaseInfo = (version: version, downloadURL: downloadURL, sha256URL: sha256URL, size: size)
        state = .downloading(progress: 0.0, bytesWritten: 0, totalBytes: size)

        // If a SHA256 checksum asset is provided, fetch it first to verify during staging
        if let shaURL = sha256URL {
            fetchRemoteChecksum(from: shaURL) { [weak self] checksum in
                self?.currentExpectedSHA256 = checksum
                self?.beginAssetDownload(from: downloadURL)
            }
        } else {
            currentExpectedSHA256 = nil
            beginAssetDownload(from: downloadURL)
        }
    }

    /// Relaunches the application with the newly staged bundle and terminates the current instance.
    func installAndRelaunch() {
        guard case let .readyToRestart(stagedAppURL, targetAppURL) = state else { return }

        let pid = ProcessInfo.processInfo.processIdentifier
        let oldPath = targetAppURL.path
        let newPath = stagedAppURL.path

        // Spawn a detached POSIX shell script to swap the app bundle and relaunch after PID exits.
        let script = """
        (
            while kill -0 "\(pid)" 2>/dev/null; do
                sleep 0.1
            done
            rm -rf "\(oldPath)"
            cp -R "\(newPath)" "\(oldPath)"
            xattr -dr com.apple.quarantine "\(oldPath)" 2>/dev/null || true
            /usr/bin/open "\(oldPath)"
        ) >/dev/null 2>&1 &
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]

        do {
            try process.run()
            NSApplication.shared.terminate(nil)
        } catch {
            state = .failed(error: "Failed to spawn update helper: \(error.localizedDescription)")
        }
    }

    // MARK: - Internal Processing

    private func processRelease(_ release: GitHubRelease) {
        let remoteRawTag = release.tagName
        let remoteClean = remoteRawTag.hasPrefix("v") ? String(remoteRawTag.dropFirst()) : remoteRawTag

        let hasNewerVersion = Self.isRemoteVersion(remoteClean, newerThan: currentVersionString)

        DispatchQueue.main.async {
            if hasNewerVersion {
                // Find Tranz-macOS.zip
                guard let zipAsset = release.assets.first(where: { $0.name == "Tranz-macOS.zip" }),
                      let downloadURL = URL(string: zipAsset.browserDownloadUrl),
                      let htmlURL = URL(string: release.htmlUrl) else {
                    self.state = .failed(error: "Release \(remoteRawTag) has no Tranz-macOS.zip asset.")
                    return
                }

                let shaAsset = release.assets.first(where: { $0.name.contains(".sha256") || $0.name.hasSuffix(".sha256") })
                let shaURL = shaAsset.flatMap { URL(string: $0.browserDownloadUrl) }

                self.state = .updateAvailable(
                    version: remoteClean,
                    releaseNotes: release.body ?? release.name ?? "New release available.",
                    htmlURL: htmlURL,
                    downloadURL: downloadURL,
                    sha256URL: shaURL,
                    sizeBytes: zipAsset.size
                )
            } else {
                self.state = .upToDate(currentVersion: self.currentVersionString)
            }
        }
    }

    private func fetchRemoteChecksum(from url: URL, completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data, let text = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            // Checksum format: "hash  filename" or just "hash"
            let hash = text.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .first ?? ""
            completion(hash.isEmpty ? nil : hash.lowercased())
        }.resume()
    }

    private func beginAssetDownload(from url: URL) {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        self.downloadSession = session

        var request = URLRequest(url: url)
        request.setValue("Tranz-App/\(currentVersionString)", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        self.activeDownloadTask = task
        task.resume()
    }

    private func stageDownloadedArchive(at tempURL: URL) {
        DispatchQueue.main.async {
            self.state = .verifying
        }

        // 1. Verify SHA256 if expected
        if let expectedSHA = currentExpectedSHA256, !expectedSHA.isEmpty {
            do {
                let fileData = try Data(contentsOf: tempURL, options: .mappedIfSafe)
                let hash = SHA256.hash(data: fileData)
                let computedHex = hash.map { String(format: "%02x", $0) }.joined()

                if computedHex.lowercased() != expectedSHA.lowercased() {
                    DispatchQueue.main.async {
                        self.state = .failed(error: "Integrity check failed: SHA256 mismatch.")
                    }
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .failed(error: "Failed to compute checksum: \(error.localizedDescription)")
                }
                return
            }
        }

        // 2. Prepare staging directory
        let fileManager = FileManager.default
        let stagingDir = fileManager.temporaryDirectory.appendingPathComponent("TranzUpdate_\(UUID().uuidString)")

        do {
            try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            self.stagedDirectoryURL = stagingDir

            // 3. Extract using ditto
            let dittoProcess = Process()
            dittoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            dittoProcess.arguments = ["-x", "-k", tempURL.path, stagingDir.path]
            try dittoProcess.run()
            dittoProcess.waitUntilExit()

            guard dittoProcess.terminationStatus == 0 else {
                DispatchQueue.main.async {
                    self.state = .failed(error: "Failed to unpack application archive.")
                }
                return
            }

            // 4. Locate extracted Tranz.app
            let stagedApp = stagingDir.appendingPathComponent("Tranz.app")
            guard fileManager.fileExists(atPath: stagedApp.path) else {
                DispatchQueue.main.async {
                    self.state = .failed(error: "Archive does not contain Tranz.app bundle.")
                }
                return
            }

            // 5. Determine target app URL
            var targetApp = Bundle.main.bundleURL
            if targetApp.pathExtension != "app" {
                // If running in development/CLI build, target standard build/Tranz.app
                let fallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/Tranz.app")
                if fileManager.fileExists(atPath: fallback.path) {
                    targetApp = fallback
                }
            }

            DispatchQueue.main.async {
                self.state = .readyToRestart(stagedAppURL: stagedApp, targetAppURL: targetApp)
            }
        } catch {
            DispatchQueue.main.async {
                self.state = .failed(error: "Staging error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Semver Comparator

    /// Compares two semantic version strings (e.g. "1.0.3" vs "1.0.0"). Returns true if remote > current.
    static func isRemoteVersion(_ remote: String, newerThan current: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "^v", with: "", options: .regularExpression)
        let cleanCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "^v", with: "", options: .regularExpression)

        let remoteParts = cleanRemote.components(separatedBy: ".").compactMap { Int($0.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "") }
        let currentParts = cleanCurrent.components(separatedBy: ".").compactMap { Int($0.components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "") }

        let count = max(remoteParts.count, currentParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}

// MARK: - URLSessionDownloadDelegate

extension UpdateCoordinator: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0.0

        DispatchQueue.main.async {
            self.state = .downloading(
                progress: min(max(progress, 0.0), 1.0),
                bytesWritten: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : (self.currentReleaseInfo?.size ?? 0)
            )
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move temporary download file to prevent deletion by OS before staging
        let tempZip = FileManager.default.temporaryDirectory.appendingPathComponent("Tranz-Update-\(UUID().uuidString).zip")
        do {
            try FileManager.default.moveItem(at: location, to: tempZip)
            stageDownloadedArchive(at: tempZip)
        } catch {
            DispatchQueue.main.async {
                self.state = .failed(error: "Failed to persist downloaded archive: \(error.localizedDescription)")
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, (error as NSError).code != NSURLErrorCancelled {
            DispatchQueue.main.async {
                self.state = .failed(error: "Download failed: \(error.localizedDescription)")
            }
        }
    }
}
