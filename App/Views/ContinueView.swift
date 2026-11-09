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

    @State private var isEditing = false
    @State private var confirmClearAll = false

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
                                .overlay {
                                    if isEditing {
                                        RemoveOverlay { remove(video) }
                                    }
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        remove(video)
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
            .toolbar {
                if !watched.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if isEditing {
                            Button("Clear All", role: .destructive) { confirmClearAll = true }
                                .font(.title3)
                        }
                        Button(isEditing ? "Done" : "Remove…") {
                            withAnimation { isEditing.toggle() }
                        }
                        .font(.title3.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
            }
            .confirmationDialog(
                "Remove all \(watched.count) videos from Continue Watching?",
                isPresented: $confirmClearAll,
                titleVisibility: .visible
            ) {
                Button("Remove All", role: .destructive) {
                    withAnimation {
                        watched.forEach { $0.lastWatched = nil }
                        try? context.save()
                        isEditing = false
                    }
                }
            } message: {
                Text("Bookmarks, favourites and downloads are kept.")
            }
            .onChange(of: watched.isEmpty) { _, empty in
                if empty { isEditing = false }
            }
        }
    }

    /// Takes it off this list only; its place, bookmarks, favourite and download are kept.
    private func remove(_ video: Video) {
        withAnimation {
            video.lastWatched = nil
            try? context.save()
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

/// Covers a card while removing: one big, obvious button.
private struct RemoveOverlay: View {
    let onRemove: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.35))
            Button(action: onRemove) {
                Label("Remove", systemImage: "minus.circle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 14)
                    .background(Color.red, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .transition(.opacity)
    }
}
