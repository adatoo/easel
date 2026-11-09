import SwiftUI

/// Everything saved on the iPad, playable without internet.
struct DownloadsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let downloads = app.downloads
        NavigationStack {
            List {
                if let error = downloads.lastError {
                    Text(error).foregroundStyle(.red)
                }
                if !downloads.activeDownloads.isEmpty {
                    Section("Downloading") {
                        ForEach(downloads.activeDownloads, id: \.video.slug) { entry in
                            HStack(spacing: 16) {
                                Thumbnail(url: entry.video.thumbnailURL)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.video.title).font(.headline)
                                    ProgressView(value: entry.progress)
                                    Text("\(Int(entry.progress * 100))%")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Button("Cancel", role: .destructive) { downloads.cancel(entry.video.slug) }
                                    .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                Section {
                    ForEach(downloads.downloads) { record in
                        Button {
                            app.open(record.info)
                        } label: {
                            HStack(spacing: 16) {
                                Thumbnail(url: record.info.thumbnailURL)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.title).font(.headline)
                                    if !record.tutor.isEmpty {
                                        Text(record.tutor).foregroundStyle(.secondary)
                                    }
                                    Text(ByteText.string(record.bytes))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("Remove", role: .destructive) { downloads.delete(record.slug) }
                        }
                    }
                } header: {
                    if !downloads.downloads.isEmpty {
                        Text("On this iPad · \(ByteText.string(downloads.totalBytes))")
                    }
                } footer: {
                    if !downloads.downloads.isEmpty {
                        Text("Swipe left on a video to remove it.")
                    }
                }
            }
            .overlay {
                if downloads.downloads.isEmpty, downloads.activeDownloads.isEmpty {
                    ContentUnavailableView(
                        "No downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Tap Download in the player or on a video page to watch it without internet.")
                    )
                }
            }
            .navigationTitle("Downloads")
        }
    }
}

private struct Thumbnail: View {
    let url: URL?

    var body: some View {
        Color.secondary.opacity(0.15)
            .frame(width: 160, height: 90)
            .overlay {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "photo").foregroundStyle(.tertiary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
