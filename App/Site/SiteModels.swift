import Foundation

/// A video (or a series of them) as the site describes it.
struct VideoInfo: Identifiable, Hashable, Sendable {
    var id: Int
    var slug: String
    var title: String
    var tutor: String = ""
    var tutorID: Int = 0
    var thumbnail: String = ""
    var summary: String = ""
    var dateLive: Date? = nil
    /// The session's nominal length from the site (not always the recording's real length).
    var durationMinutes: Int = 0
    var isSeries: Bool = false
    /// A live session that hasn't happened yet.
    var isUpcoming: Bool = false
    /// Whether her account can watch it.
    var accessible: Bool = true
    var hasSubtitles: Bool = false

    var thumbnailURL: URL? { RawUmber.thumbnail(thumbnail) }
    var previewURL: URL? { RawUmber.preview(thumbnail) }
}

extension VideoInfo {
    /// From the compact form the data script returns (SiteScripts.api).
    init?(site dict: [String: Any]) {
        guard let slug = dict["slug"] as? String, !slug.isEmpty else { return nil }
        self.init(
            id: (dict["id"] as? Int) ?? 0,
            slug: slug,
            title: (dict["title"] as? String) ?? slug,
            tutor: (dict["tutor"] as? String) ?? "",
            tutorID: (dict["tutorId"] as? Int) ?? 0,
            thumbnail: (dict["thumbnail"] as? String) ?? "",
            summary: (dict["description"] as? String) ?? "",
            dateLive: (dict["dateLive"] as? String).flatMap(VideoInfo.parseDate),
            durationMinutes: (dict["duration"] as? Int) ?? 0,
            isSeries: (dict["isSeries"] as? Bool) ?? false,
            isUpcoming: (dict["inTheFuture"] as? Bool) ?? false,
            accessible: (dict["accessible"] as? Bool) ?? true,
            hasSubtitles: (dict["hasSubtitles"] as? Bool) ?? false
        )
    }

    static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    /// The weekly sessions are all titled "<Model>: An online portrait drawing session".
    /// Cards show just the first part, and the kind of session underneath.
    private var sessionTitleSplit: Range<String.Index>? {
        title.range(of: ": An online ", options: .caseInsensitive)
    }

    var displayTitle: String {
        guard let split = sessionTitleSplit else { return title }
        let name = title[..<split.lowerBound].trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? title : name
    }

    /// "Portrait" or "Figure" for the weekly sessions.
    var sessionKind: String? {
        guard let split = sessionTitleSplit else { return nil }
        let rest = title[split.upperBound...].lowercased()
        if rest.contains("portrait") { return "Portrait" }
        if rest.contains("figure") { return "Figure" }
        return nil
    }

    /// The line under a card's title: "Portrait · Luca Indraccolo · 8 Nov".
    var cardSubtitle: String {
        var parts: [String] = []
        if isSeries { parts.append("Series") }
        if let sessionKind { parts.append(sessionKind) }
        if !tutor.isEmpty { parts.append(tutor) }
        if !isSeries, !isUpcoming, let dateLive { parts.append(VideoInfo.shortDate(dateLive)) }
        return parts.joined(separator: " · ")
    }

    /// "Wed 11 Nov · 8 PM" for a session that hasn't happened yet.
    var liveBadge: String? {
        guard isUpcoming, let dateLive else { return nil }
        let day = dateLive.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return day + " · " + dateLive.formatted(date: .omitted, time: .shortened)
    }

    static func shortDate(_ date: Date) -> String {
        if Calendar.current.isDate(date, equalTo: Date.now, toGranularity: .year) {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

/// One of Raw Umber's curated playlists.
struct PlaylistInfo: Identifiable, Hashable, Sendable {
    var id: Int
    var slug: String
    var name: String
    var about: String = ""

    init?(site dict: [String: Any]) {
        guard let slug = dict["slug"] as? String, !slug.isEmpty else { return nil }
        id = (dict["id"] as? Int) ?? 0
        self.slug = slug
        name = (dict["name"] as? String) ?? slug
        about = (dict["about"] as? String) ?? ""
    }
}

struct Tutor: Identifiable, Hashable, Sendable {
    var id: Int
    var name: String

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}

/// Who the site says is signed in.
struct SiteSession: Sendable {
    var loggedIn = false
    var level = "none"
    var subscribed = false
    var tutors: [Tutor] = []
}

/// A link the site lists beside a video: a materials list, reference photos and so on.
struct ExtraLink: Identifiable, Hashable, Sendable {
    var title: String
    var url: URL
    var id: String { url.absoluteString + title }

    /// Files (the model packs are zips) open in Safari, which can save them.
    var isFile: Bool {
        ["zip", "pdf", "jpg", "jpeg", "png"].contains(url.pathExtension.lowercased())
    }
}

/// Everything on a video's (or series') page.
struct VideoPage: Sendable {
    var video: VideoInfo
    /// The parts of a series, in order. Empty for a single video.
    var parts: [VideoInfo] = []
    var trailer: VideoInfo?
    var related: [VideoInfo] = []
    var extras: [ExtraLink] = []
}

struct SearchPage: Sendable {
    var videos: [VideoInfo]
    var count: Int
}

// MARK: - Search filters (the values the site's own search page sends)

enum Subject: String, CaseIterable, Identifiable, Sendable {
    case human = "Human"
    case animal = "Animal"
    case landscape = "Landscape"
    case stillLife = "StillLife"
    case other = "Other"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .human: return "People"
        case .animal: return "Animals"
        case .landscape: return "Landscape"
        case .stillLife: return "Still life"
        case .other: return "Other"
        }
    }
}

enum ArtMaterial: String, CaseIterable, Identifiable, Sendable {
    case oils = "Oils"
    case acrylics = "Acrylics"
    case charcoal = "Charcoal"
    case chalk = "Chalk"
    case watercolour = "Watercolour"
    case gouache = "Gouache"
    case pencil = "Pencil"
    case penAndInk = "PenAndInk"
    case pastels = "Pastels"
    case panPastel = "PanPastel"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oils: return "Oil paints"
        case .penAndInk: return "Pen and ink"
        default: return rawValue
        }
    }
}

enum VideoType: String, CaseIterable, Identifiable, Sendable {
    case regular = "RegularSession"
    case special = "SpecialSession"
    case short = "Short"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .regular: return "Weekly sessions"
        case .special: return "Special sessions"
        case .short: return "Short videos"
        }
    }
}

struct SearchQuery: Hashable, Sendable {
    var text = ""
    var subject: Subject?
    var materials: Set<ArtMaterial> = []
    var tutor: Tutor?
    var type: VideoType?

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isEmpty: Bool {
        trimmedText.isEmpty && subject == nil && materials.isEmpty && tutor == nil && type == nil
    }

    /// The request the site's search page sends for these choices.
    func json(offset: Int, count: Int) -> String {
        var body: [String: Any] = ["FreeText": trimmedText, "Count": count, "Offset": offset]
        if let subject { body["SubjectType"] = subject.rawValue }
        if !materials.isEmpty { body["Materials"] = materials.map(\.rawValue).sorted() }
        if let type { body["VideoTypes"] = [type.rawValue] }
        if let tutor { body["TutorId"] = tutor.id }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
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

    /// "23 min left".
    static func remaining(_ seconds: Double) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        return "\(minutes) min left"
    }
}
