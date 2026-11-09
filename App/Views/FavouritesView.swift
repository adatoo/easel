import SwiftData
import SwiftUI

struct FavouritesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<Video> { $0.isFavourite },
        sort: [SortDescriptor(\Video.favouritedAt, order: .reverse)]
    )
    private var favourites: [Video]

    var body: some View {
        NavigationStack {
            Group {
                if favourites.isEmpty {
                    ContentUnavailableView(
                        "No favourites yet",
                        systemImage: "heart",
                        description: Text("Tap the heart on any video to keep it here.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: VideoGrid.columns, spacing: 28) {
                            ForEach(favourites) { video in
                                VideoCard(
                                    video: video.info,
                                    isFavourite: true,
                                    progress: video.progress,
                                    isDownloaded: app.downloads.isDownloaded(video.slug),
                                    onOpen: { app.open(video.info) },
                                    onToggleFavourite: { VideoStore.toggleFavourite(video.info, in: context) }
                                )
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Favourites")
        }
    }
}
