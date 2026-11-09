import SwiftData
import SwiftUI

/// The site's video library, searchable, loaded a page at a time as she scrolls.
struct LibraryView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Video> { $0.isFavourite }) private var favourites: [Video]

    @State private var searchText = ""
    @State private var videos: [VideoInfo] = []
    @State private var isLoading = false
    @State private var reachedEnd = false
    @State private var errorMessage: String?
    @State private var generation = 0
    @State private var fetched = 0

    private let catalog = Catalog()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: VideoGrid.columns, spacing: 28) {
                    ForEach(videos) { video in
                        VideoCard(
                            video: video,
                            isFavourite: favouriteIDs.contains(video.id),
                            onOpen: { app.open(video) },
                            onToggleFavourite: { VideoStore.toggleFavourite(video, in: context) }
                        )
                        .onAppear {
                            if video.id == videos.last?.id {
                                Task { await loadMore() }
                            }
                        }
                    }
                }
                .padding(24)
                footer
            }
            .navigationTitle("Library")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search titles, tutors, materials"
            )
            .task(id: searchText) {
                if !searchText.isEmpty {
                    try? await Task.sleep(for: .milliseconds(450))
                }
                guard !Task.isCancelled else { return }
                await reload()
            }
            .refreshable { await reload() }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if isLoading {
            ProgressView()
                .controlSize(.large)
                .padding(.bottom, 40)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage).foregroundStyle(.secondary)
                Button("Try again") { Task { await reload() } }
                    .buttonStyle(.bordered)
            }
            .padding(.bottom, 40)
        } else if videos.isEmpty {
            if searchText.isEmpty {
                ContentUnavailableView("No videos", systemImage: "film.stack")
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private var favouriteIDs: Set<Int> {
        Set(favourites.map(\.videoID))
    }

    private func reload() async {
        generation += 1
        videos = []
        fetched = 0
        reachedEnd = false
        errorMessage = nil
        await fetchPage(generation: generation)
    }

    private func loadMore() async {
        guard !isLoading, !reachedEnd, errorMessage == nil else { return }
        await fetchPage(generation: generation)
    }

    private func fetchPage(generation requested: Int) async {
        isLoading = true
        defer {
            if requested == generation { isLoading = false }
        }
        do {
            let cookies = await app.web.siteCookies()
            let page = try await catalog.search(searchText, offset: fetched, cookies: cookies)
            guard requested == generation else { return }
            fetched += page.videos.count
            let known = Set(videos.map(\.id))
            videos += page.videos.filter { !known.contains($0.id) }
            reachedEnd = page.videos.count < Catalog.pageSize
        } catch {
            guard requested == generation, !Task.isCancelled else { return }
            errorMessage = "Couldn't load the videos. Check the connection and try again."
        }
    }
}
