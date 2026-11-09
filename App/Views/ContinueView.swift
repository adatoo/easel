import SwiftData
import SwiftUI

/// Videos she has started, most recent first, ready to pick up where she stopped.
struct ContinueView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Video> { $0.lastWatched != nil },
        sort: [SortDescriptor(\Video.lastWatched, order: .reverse)]
    )
    private var watched: [Video]

    var body: some View {
        NavigationStack {
            Group {
                if watched.isEmpty {
                    ContentUnavailableView(
                        "Nothing watched yet",
                        systemImage: "play.circle",
                        description: Text("Videos you start in Easel appear here, ready to pick up where you stopped.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: VideoGrid.columns, spacing: 28) {
                            ForEach(watched) { video in
                                VideoCard(
                                    video: video.info,
                                    isFavourite: video.isFavourite,
                                    progress: video.progress,
                                    detail: detail(for: video),
                                    isDownloaded: app.downloads.isDownloaded(video.slug),
                                    onOpen: { app.open(video.info) },
                                    onToggleFavourite: { VideoStore.toggleFavourite(video.info, in: context) }
                                )
                                .contextMenu {
                                    Button(role: .destructive) {
                                        video.lastWatched = nil
                                        try? context.save()
                                    } label: {
                                        Label("Remove from Continue", systemImage: "minus.circle")
                                    }
                                }
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Continue Watching")
        }
    }

    private func detail(for video: Video) -> String {
        var parts: [String] = []
        if video.finished {
            parts.append("Watched")
        } else if video.lastPosition > 0 {
            parts.append("Stopped at \(Timecode.string(video.lastPosition))")
        }
        let count = video.bookmarks?.count ?? 0
        if count > 0 {
            parts.append(count == 1 ? "1 bookmark" : "\(count) bookmarks")
        }
        return parts.joined(separator: " · ")
    }
}
