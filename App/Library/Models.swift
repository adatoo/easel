import Foundation
import SwiftData

/// A video she has favourited, watched or bookmarked.
///
/// Every property has a default and the relationship is optional, so the store can be synced
/// with CloudKit later (add the iCloud capability) without a migration.
@Model
final class Video {
    var videoID: Int = 0
    var slug: String = ""
    var title: String = ""
    var tutor: String = ""
    var thumbnail: String = ""
    var summary: String = ""
    var dateLive: Date?
    var durationMinutes: Int = 0
    var isFavourite: Bool = false
    var favouritedAt: Date?
    /// Where she stopped, in seconds; 0 once she reaches the end.
    var lastPosition: Double = 0
    /// The recording's real length in seconds, once it has played.
    var knownDuration: Double = 0
    var lastWatched: Date?
    var finished: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Bookmark.video)
    var bookmarks: [Bookmark]? = []

    init(_ info: VideoInfo) {
        videoID = info.id
        slug = info.slug
        update(from: info)
    }

    func update(from info: VideoInfo) {
        if info.id != 0 { videoID = info.id }
        if !info.title.isEmpty { title = info.title }
        if !info.tutor.isEmpty { tutor = info.tutor }
        if !info.thumbnail.isEmpty { thumbnail = info.thumbnail }
        if !info.summary.isEmpty { summary = info.summary }
        if let date = info.dateLive { dateLive = date }
        if info.durationMinutes > 0 { durationMinutes = info.durationMinutes }
    }

    var info: VideoInfo {
        VideoInfo(
            id: videoID, slug: slug, title: title, tutor: tutor, thumbnail: thumbnail,
            summary: summary, dateLive: dateLive, durationMinutes: durationMinutes,
            isSeries: false, isUpcoming: false
        )
    }

    /// How far through she is, for the bar on a card.
    var progress: Double? {
        guard knownDuration > 0 else { return nil }
        if finished { return 1 }
        guard lastPosition > 0 else { return nil }
        return min(1, lastPosition / knownDuration)
    }

    var sortedBookmarks: [Bookmark] {
        (bookmarks ?? []).sorted { $0.time < $1.time }
    }
}

/// A moment in a video she wants to come back to.
@Model
final class Bookmark {
    var time: Double = 0
    var note: String = ""
    var createdAt: Date = Date.now
    var video: Video?

    init(time: Double, note: String = "") {
        self.time = time
        self.note = note
    }
}
