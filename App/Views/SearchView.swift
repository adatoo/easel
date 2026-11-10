import SwiftData
import SwiftUI

/// Search: before she types, ways in by subject, materials, tutor and playlist; after, results
/// she can narrow with the site's own filters.
struct SearchView: View {
    @Environment(AppModel.self) private var app

    @Query(filter: #Predicate<Video> { $0.lastWatched != nil })
    private var watched: [Video]

    @State private var query = SearchQuery()
    @State private var notWatchedOnly = false
    @State private var results: [VideoInfo] = []
    @State private var total = 0
    @State private var fetched = 0
    @State private var isLoading = false
    @State private var reachedEnd = false
    @State private var failed = false
    @State private var generation = 0
    @FocusState private var fieldFocused: Bool

    private var isBrowsing: Bool { query.isEmpty && !notWatchedOnly }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                searchField
                if isBrowsing {
                    browse
                } else {
                    filterBar
                    resultsGrid
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 30)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.ground)
        .toolbar(.hidden, for: .navigationBar)
        .task(
            id: SearchKey(
                query: query, notWatchedOnly: notWatchedOnly, siteVersion: app.siteVersion)
        ) {
            // Wait for a pause in typing before asking the site.
            if !query.trimmedText.isEmpty {
                try? await Task.sleep(for: .milliseconds(450))
            }
            guard !Task.isCancelled else { return }
            await reload()
        }
    }

    // MARK: - The field

    private var searchField: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Theme.secondary)
            TextField(
                "",
                text: $query.text,
                prompt: Text("Search titles, tutors and materials").foregroundStyle(Theme.secondary)
            )
            .font(.system(size: 20))
            .foregroundStyle(Theme.text)
            .submitLabel(.search)
            .autocorrectionDisabled()
            .focused($fieldFocused)
            if !isBrowsing {
                Button {
                    query = SearchQuery()
                    notWatchedOnly = false
                    fieldFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .frame(height: 64)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(fieldFocused ? Theme.accent : Theme.line, lineWidth: 1)
        }
        .padding(.horizontal, Theme.gutter)
    }

    // MARK: - Before typing

    private struct Shortcut: Identifiable {
        let id: String
        let icon: String
        let apply: (inout SearchQuery) -> Void
    }

    private static let shortcuts: [Shortcut] = [
        Shortcut(id: "Portraits", icon: "person.crop.square") { $0.text = "portrait" },
        Shortcut(id: "Figures", icon: "figure.stand") { $0.text = "figure" },
        Shortcut(id: "Still life", icon: "cup.and.saucer") { $0.subject = .stillLife },
        Shortcut(id: "Landscapes", icon: "mountain.2") { $0.subject = .landscape },
        Shortcut(id: "Animals", icon: "pawprint") { $0.subject = .animal },
        Shortcut(id: "Master copies", icon: "photo.artframe") { $0.text = "mastercopy" },
    ]

    @ViewBuilder
    private var browse: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Subject")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 6), spacing: 16
            ) {
                ForEach(Self.shortcuts) { shortcut in
                    Button {
                        var next = SearchQuery()
                        shortcut.apply(&next)
                        query = next
                    } label: {
                        VStack(alignment: .leading) {
                            Image(systemName: shortcut.icon)
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(Theme.accent)
                            Spacer(minLength: 8)
                            Text(shortcut.id)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .frame(height: 124)
                        .background(
                            Theme.surface,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, Theme.gutter)

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Materials")
                .padding(.horizontal, Theme.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ArtMaterial.allCases) { material in
                        Button(material.label) {
                            var next = SearchQuery()
                            next.materials = [material]
                            query = next
                        }
                        .buttonStyle(PillButtonStyle(kind: .secondary, height: 50))
                    }
                }
                .padding(.horizontal, Theme.gutter)
            }
        }

        if !app.api.session.tutors.isEmpty {
            RowSection("Tutors") {
                ForEach(app.api.session.tutors) { tutor in
                    Button {
                        var next = SearchQuery()
                        next.tutor = tutor
                        query = next
                    } label: {
                        VStack(spacing: 10) {
                            Text(tutor.initials)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 88, height: 88)
                                .background(Theme.raised, in: Circle())
                            Text(tutor.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(width: 112)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        if !app.api.playlists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Playlists from Raw Umber")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 16)], spacing: 16) {
                    ForEach(app.api.playlists) { playlist in
                        PlaylistTile(playlist: playlist)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    // MARK: - Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Menu {
                    Button("Any subject") { query.subject = nil }
                    ForEach(Subject.allCases) { subject in
                        Button {
                            query.subject = subject
                        } label: {
                            menuLabel(subject.label, selected: query.subject == subject)
                        }
                    }
                } label: {
                    FilterChip(
                        title: query.subject?.label ?? "Subject", active: query.subject != nil,
                        isMenu: true)
                }

                Menu {
                    Button("Any materials") { query.materials = [] }
                    ForEach(ArtMaterial.allCases) { material in
                        Button {
                            if query.materials.contains(material) {
                                query.materials.remove(material)
                            } else {
                                query.materials.insert(material)
                            }
                        } label: {
                            menuLabel(material.label, selected: query.materials.contains(material))
                        }
                    }
                } label: {
                    FilterChip(
                        title: materialsTitle, active: !query.materials.isEmpty, isMenu: true)
                }

                Menu {
                    Button("Any tutor") { query.tutor = nil }
                    ForEach(app.api.session.tutors) { tutor in
                        Button {
                            query.tutor = tutor
                        } label: {
                            menuLabel(tutor.name, selected: query.tutor == tutor)
                        }
                    }
                } label: {
                    FilterChip(
                        title: query.tutor?.name ?? "Tutor", active: query.tutor != nil,
                        isMenu: true)
                }

                Menu {
                    Button("Any kind") { query.type = nil }
                    ForEach(VideoType.allCases) { type in
                        Button {
                            query.type = type
                        } label: {
                            menuLabel(type.label, selected: query.type == type)
                        }
                    }
                } label: {
                    FilterChip(
                        title: query.type?.label ?? "Kind", active: query.type != nil, isMenu: true)
                }

                Rectangle().fill(Theme.line).frame(width: 1, height: 28).padding(.horizontal, 6)

                Button {
                    notWatchedOnly.toggle()
                } label: {
                    FilterChip(title: "Not watched", active: notWatchedOnly, isMenu: false)
                }
                .buttonStyle(.plain)

                if total > 0 {
                    Text(total == 1 ? "1 video" : "\(total) videos")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.secondary)
                        .padding(.leading, 10)
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private var materialsTitle: String {
        if query.materials.isEmpty { return "Materials" }
        if query.materials.count == 1, let only = query.materials.first { return only.label }
        return "\(query.materials.count) materials"
    }

    @ViewBuilder
    private func menuLabel(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    // MARK: - Results

    private var visibleResults: [VideoInfo] {
        guard notWatchedOnly else { return results }
        let seen = Set(watched.map(\.slug))
        return results.filter { !seen.contains($0.slug) }
    }

    @ViewBuilder
    private var resultsGrid: some View {
        let visible = visibleResults
        VideoGrid {
            ForEach(visible, id: \.slug) { video in
                VideoCard(video, width: nil) { app.open(video) }
                    .onAppear {
                        if video.slug == visible.last?.slug {
                            Task { await loadMore() }
                        }
                    }
            }
        }

        if isLoading {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
        } else if failed {
            VStack(spacing: 14) {
                Text("Couldn't search. Check the internet connection and try again.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.secondary)
                Button("Try again") { Task { await reload() } }
                    .buttonStyle(PillButtonStyle(kind: .secondary, height: 48))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else if reachedEnd {
            if visible.isEmpty {
                ContentUnavailableView(
                    "No videos found",
                    systemImage: "magnifyingglass",
                    description: Text("Try fewer filters or a different word.")
                )
                .padding(.top, 20)
            }
        } else if visible.isEmpty {
            if fetched > 0 {
                // Everything loaded so far is hidden by "Not watched".
                VStack(spacing: 14) {
                    Text("Nothing unwatched in the first \(fetched) results.")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.secondary)
                    Button("Keep looking") { Task { await loadMore() } }
                        .buttonStyle(PillButtonStyle(kind: .secondary, height: 48))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            }
        } else {
            Button("Show more") { Task { await loadMore() } }
                .buttonStyle(PillButtonStyle(kind: .secondary, height: 48))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
    }

    private func reload() async {
        generation += 1
        results = []
        total = 0
        fetched = 0
        reachedEnd = false
        failed = false
        guard !query.isEmpty || notWatchedOnly else { return }
        await fetchPage(generation: generation)
    }

    private func loadMore() async {
        guard !isLoading, !reachedEnd, !failed else { return }
        await fetchPage(generation: generation)
    }

    private func fetchPage(generation requested: Int) async {
        isLoading = true
        defer {
            if requested == generation { isLoading = false }
        }
        do {
            let page = try await app.api.search(query, offset: fetched)
            guard requested == generation else { return }
            fetched += page.videos.count
            total = page.count
            let known = Set(results.map(\.slug))
            results += page.videos.filter { !known.contains($0.slug) }
            reachedEnd = page.videos.count < SiteAPI.pageSize
        } catch {
            guard requested == generation, !Task.isCancelled else { return }
            failed = true
        }
    }
}

/// What a search depends on: when it changes, the search runs again.
private struct SearchKey: Hashable {
    var query: SearchQuery
    var notWatchedOnly: Bool
    var siteVersion: Int
}

/// One of the filter buttons above the results.
private struct FilterChip: View {
    let title: String
    let active: Bool
    let isMenu: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if isMenu {
                Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold))
            }
        }
        .font(.system(size: 16, weight: active ? .semibold : .medium))
        .lineLimit(1)
        .padding(.horizontal, 18)
        .frame(height: 48)
        .foregroundStyle(active ? Theme.accent : Theme.text)
        .background(active ? Color.clear : Theme.raised, in: Capsule())
        .overlay {
            if active {
                Capsule().strokeBorder(Theme.accent, lineWidth: 1.5)
            }
        }
        .contentShape(Capsule())
    }
}
