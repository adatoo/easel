import Foundation

/// A video as the site describes it, from the search API or from a video page.
struct VideoInfo: Identifiable, Hashable, Sendable {
    var id: Int
    var slug: String
    var title: String
    var tutor: String
    var thumbnail: String
    var summary: String
    var dateLive: Date?
    /// The session's nominal length from the site (not always the recording's real length).
    var durationMinutes: Int
    var isSeries: Bool
    var isUpcoming: Bool

    var thumbnailURL: URL? { RawUmber.thumbnail(thumbnail) }
}

extension VideoInfo {
    /// Builds one from the dictionary the page bridge posts (EaselBridge.swift).
    init?(bridge dict: [String: Any]) {
        guard let slug = dict["slug"] as? String, !slug.isEmpty else { return nil }
        self.init(
            id: (dict["id"] as? Int) ?? 0,
            slug: slug,
            title: (dict["title"] as? String) ?? slug,
            tutor: (dict["tutor"] as? String) ?? "",
            thumbnail: (dict["thumbnail"] as? String) ?? "",
            summary: (dict["description"] as? String) ?? "",
            dateLive: (dict["dateLive"] as? String).flatMap(VideoInfo.parseDate),
            durationMinutes: (dict["duration"] as? Int) ?? 0,
            isSeries: (dict["isSeries"] as? Bool) ?? false,
            isUpcoming: (dict["inTheFuture"] as? Bool) ?? false
        )
    }

    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}

/// Playback times as "12:34" or "1:02:03".
enum Timecode {
    static func string(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}
