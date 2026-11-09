import Foundation
import SwiftData

/// Finding and updating the videos Easel keeps.
@MainActor
enum VideoStore {
    static func find(id: Int, in context: ModelContext) -> Video? {
        var descriptor = FetchDescriptor<Video>(predicate: #Predicate<Video> { $0.videoID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func find(slug: String, in context: ModelContext) -> Video? {
        var descriptor = FetchDescriptor<Video>(predicate: #Predicate<Video> { $0.slug == slug })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func find(_ info: VideoInfo, in context: ModelContext) -> Video? {
        if info.id != 0, let video = find(id: info.id, in: context) { return video }
        return find(slug: info.slug, in: context)
    }

    /// The stored video for this one, created the first time it's needed.
    @discardableResult
    static func upsert(_ info: VideoInfo, in context: ModelContext) -> Video {
        if let video = find(info, in: context) {
            video.update(from: info)
            return video
        }
        let video = Video(info)
        context.insert(video)
        return video
    }

    static func toggleFavourite(_ info: VideoInfo, in context: ModelContext) {
        let video = upsert(info, in: context)
        video.isFavourite.toggle()
        video.favouritedAt = video.isFavourite ? Date.now : nil
        try? context.save()
    }
}
