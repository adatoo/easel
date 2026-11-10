import AVFoundation
import Foundation
import Observation

/// A video saved on the iPad for watching without internet.
struct DownloadRecord: Codable, Identifiable, Hashable {
    var slug: String
    var videoID: Int
    var title: String
    var tutor: String
    var thumbnail: String
    /// The saved .movpkg, relative to the app's home folder (the absolute path changes between installs).
    var relativePath: String
    var bytes: Int64
    var completedAt: Date

    var id: String { slug }

    var fileURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appending(path: relativePath)
    }

    var info: VideoInfo {
        VideoInfo(id: videoID, slug: slug, title: title, tutor: tutor, thumbnail: thumbnail)
    }
}

/// How sharp downloads are. 1080p is about 2.5 GB an hour, 720p about 1.5 GB.
enum DownloadQuality: String, CaseIterable, Identifiable {
    case full = "1080p"
    case smaller = "720p"

    var id: String { rawValue }

    /// The stream's variants are about 5.5, 3.4 and 1.2 Mbit/s; the download takes the lowest
    /// one at or above this.
    var minimumBitrate: Int {
        switch self {
        case .full: return 5_000_000
        case .smaller: return 3_000_000
        }
    }

    static let defaultsKey = "downloadQuality"

    static var current: DownloadQuality {
        DownloadQuality(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .full
    }
}

/// Saves HLS streams with AVAssetDownloadURLSession, which keeps going in the background, and
/// keeps an index of what's saved in Application Support/downloads.json.
@MainActor
@Observable
final class DownloadManager: NSObject {
    struct Active: Hashable {
        var video: VideoInfo
        var progress: Double
    }

    private(set) var completed: [String: DownloadRecord] = [:]
    private(set) var active: [String: Active] = [:]
    /// The last download that failed, for a message.
    private(set) var lastError: String?

    @ObservationIgnored private var session: AVAssetDownloadURLSession!
    @ObservationIgnored private var tasks: [String: AVAssetDownloadTask] = [:]
    @ObservationIgnored private var finishedLocations: [String: URL] = [:]

    override init() {
        super.init()
        completed = Self.loadIndex()
        let configuration = URLSessionConfiguration.background(
            withIdentifier: "com.datoos.easel.downloads")
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        session = AVAssetDownloadURLSession(
            configuration: configuration, assetDownloadDelegate: self, delegateQueue: .main
        )
        reconnectRunningTasks()
    }

    // MARK: - Queries

    var downloads: [DownloadRecord] {
        completed.values.sorted { $0.completedAt > $1.completedAt }
    }

    var activeDownloads: [Active] {
        active.values.sorted { $0.video.title < $1.video.title }
    }

    var totalBytes: Int64 {
        completed.values.reduce(0) { $0 + $1.bytes }
    }

    func localURL(for slug: String) -> URL? {
        guard let record = completed[slug] else { return nil }
        return FileManager.default.fileExists(atPath: record.fileURL.path) ? record.fileURL : nil
    }

    func isDownloaded(_ slug: String) -> Bool { completed[slug] != nil }

    func progress(for slug: String) -> Double? { active[slug]?.progress }

    // MARK: - Actions

    func download(_ video: VideoInfo, from streamURL: URL, cookies: [HTTPCookie]) {
        guard completed[video.slug] == nil, active[video.slug] == nil, !streamURL.isFileURL else {
            return
        }
        lastError = nil
        // Background download sessions read cookies from the shared store.
        for cookie in cookies { HTTPCookieStorage.shared.setCookie(cookie) }
        let asset = AVURLAsset(url: streamURL, options: [AVURLAssetHTTPCookiesKey: cookies])
        guard
            let task = session.makeAssetDownloadTask(
                asset: asset,
                assetTitle: video.title,
                assetArtworkData: nil,
                options: [
                    AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: DownloadQuality.current
                        .minimumBitrate
                ]
            )
        else {
            lastError = "Couldn't start downloading “\(video.displayTitle)”."
            return
        }
        task.taskDescription = Self.encode(video)
        tasks[video.slug] = task
        active[video.slug] = Active(video: video, progress: 0)
        task.resume()
    }

    func cancel(_ slug: String) {
        tasks[slug]?.cancel()
        tasks[slug] = nil
        active[slug] = nil
    }

    func delete(_ slug: String) {
        cancel(slug)
        if let record = completed.removeValue(forKey: slug) {
            try? FileManager.default.removeItem(at: record.fileURL)
            saveIndex()
        }
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - Index

    private static var indexURL: URL {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "downloads.json")
    }

    private static func loadIndex() -> [String: DownloadRecord] {
        guard let data = try? Data(contentsOf: indexURL),
            let records = try? JSONDecoder().decode([DownloadRecord].self, from: data)
        else { return [:] }
        // Drop any whose files have gone (e.g. the system reclaimed space).
        let present = records.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
        return Dictionary(present.map { ($0.slug, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(Array(completed.values)) else { return }
        try? data.write(to: Self.indexURL, options: .atomic)
    }

    // MARK: - Task bookkeeping

    /// After a relaunch, picks up downloads that carried on while Easel was closed.
    private func reconnectRunningTasks() {
        session.getAllTasks { [weak self] tasks in
            Task { @MainActor in
                guard let self else { return }
                for case let task as AVAssetDownloadTask in tasks {
                    guard let video = Self.decode(task.taskDescription) else { continue }
                    if task.state == .running || task.state == .suspended {
                        self.tasks[video.slug] = task
                        if self.active[video.slug] == nil {
                            self.active[video.slug] = Active(video: video, progress: 0)
                        }
                    }
                }
            }
        }
    }

    fileprivate func updateProgress(slug: String, fraction: Double) {
        guard var entry = active[slug] else { return }
        entry.progress = min(1, max(0, fraction))
        active[slug] = entry
    }

    fileprivate func didFinish(task: AVAssetDownloadTask, location: URL) {
        guard let video = Self.decode(task.taskDescription) else { return }
        finishedLocations[video.slug] = location
    }

    fileprivate func didComplete(task: URLSessionTask, error: Error?) {
        guard let video = Self.decode(task.taskDescription) else { return }
        let slug = video.slug
        tasks[slug] = nil
        active[slug] = nil
        let location = finishedLocations.removeValue(forKey: slug)

        if let error {
            if let location { try? FileManager.default.removeItem(at: location) }
            if (error as NSError).code != NSURLErrorCancelled {
                lastError =
                    "“\(video.displayTitle)” didn't finish downloading: \(error.localizedDescription)"
            }
            return
        }
        guard let location else { return }
        completed[slug] = DownloadRecord(
            slug: slug,
            videoID: video.id,
            title: video.title,
            tutor: video.tutor,
            thumbnail: video.thumbnail,
            relativePath: location.relativePath,
            bytes: Self.size(of: location),
            completedAt: Date.now
        )
        saveIndex()
    }

    private static func size(of url: URL) -> Int64 {
        guard
            let files = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: [.fileSizeKey])
        else {
            return 0
        }
        var total: Int64 = 0
        for case let file as URL in files {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    /// The video rides along in the task's description so a relaunch knows what each task is.
    private static func encode(_ video: VideoInfo) -> String {
        let fields: [String: String] = [
            "slug": video.slug, "id": String(video.id), "title": video.title,
            "tutor": video.tutor, "thumbnail": video.thumbnail,
        ]
        let data = (try? JSONEncoder().encode(fields)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    nonisolated private static func decode(_ description: String?) -> VideoInfo? {
        guard let data = description?.data(using: .utf8),
            let fields = try? JSONDecoder().decode([String: String].self, from: data),
            let slug = fields["slug"]
        else { return nil }
        return VideoInfo(
            id: Int(fields["id"] ?? "") ?? 0, slug: slug, title: fields["title"] ?? slug,
            tutor: fields["tutor"] ?? "", thumbnail: fields["thumbnail"] ?? ""
        )
    }
}

// The session delivers these on the main queue (delegateQueue: .main).
extension DownloadManager: AVAssetDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded loadedTimeRanges: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        let expected = timeRangeExpectedToLoad.duration.seconds
        guard expected > 0, let video = Self.decode(assetDownloadTask.taskDescription) else {
            return
        }
        let loaded = loadedTimeRanges.reduce(0.0) { $0 + $1.timeRangeValue.duration.seconds }
        let fraction = loaded / expected
        MainActor.assumeIsolated { self.updateProgress(slug: video.slug, fraction: fraction) }
    }

    nonisolated func urlSession(
        _ session: URLSession, assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        MainActor.assumeIsolated { self.didFinish(task: assetDownloadTask, location: location) }
    }

    nonisolated func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
    ) {
        MainActor.assumeIsolated { self.didComplete(task: task, error: error) }
    }
}

enum ByteText {
    static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
