import SwiftData
import SwiftUI

enum VideoGrid {
    static let columns = [GridItem(.adaptive(minimum: 280), spacing: 24)]
}

/// A video's thumbnail, title and tutor, with a heart to favourite it.
struct VideoCard: View {
    let video: VideoInfo
    var isFavourite: Bool
    var progress: Double?
    var detail: String?
    var isDownloaded = false
    var onOpen: () -> Void
    var onToggleFavourite: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 10) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if let detail, !detail.isEmpty {
                            Text(detail)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavourite) {
                Image(systemName: isFavourite ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(isFavourite ? Color.red : Color.white)
                    .frame(width: 48, height: 48)
                    .background(Color.black.opacity(0.35), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
        }
    }

    private var thumbnail: some View {
        Color.secondary.opacity(0.15)
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                AsyncImage(url: video.thumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }
            .overlay(alignment: .bottom) {
                if let progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.black.opacity(0.45))
                            Rectangle().fill(Color.accentColor).frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .overlay(alignment: .topLeading) {
                if isDownloaded {
                    Label("Downloaded", systemImage: "arrow.down.circle.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                        .padding(10)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if video.isUpcoming {
                    Text("Upcoming")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule())
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var subtitle: String {
        var parts: [String] = []
        if !video.tutor.isEmpty { parts.append(video.tutor) }
        if let date = video.dateLive { parts.append(date.formatted(date: .abbreviated, time: .omitted)) }
        return parts.joined(separator: " · ")
    }
}

/// The heart for the video page showing in the Website tab.
struct FavouriteToggle: View {
    let video: VideoInfo
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Video> { $0.isFavourite }) private var favourites: [Video]

    var body: some View {
        let isFavourite = favourites.contains { (video.id != 0 && $0.videoID == video.id) || $0.slug == video.slug }
        Button {
            VideoStore.toggleFavourite(video, in: context)
        } label: {
            Image(systemName: isFavourite ? "heart.fill" : "heart")
                .foregroundStyle(isFavourite ? Color.red : Color.primary)
        }
        .accessibilityLabel(isFavourite ? "Remove from favourites" : "Add to favourites")
    }
}
