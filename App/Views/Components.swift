import SwiftData
import SwiftUI

/// A 16:9 picture from the site.
struct Thumbnail: View {
    let url: URL?
    var cornerRadius: CGFloat = 12

    var body: some View {
        Theme.raised
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(Theme.line)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// A video as a card: picture, title, a line of detail, and a heart. It shows what Easel knows
/// about the video too: how far she is through it, whether it's watched, downloaded or locked.
struct VideoCard: View {
    let video: VideoInfo
    var width: CGFloat?
    var subtitle: String?
    /// When set, the card has a "⋯" menu with this action, e.g. "Remove from Continue watching".
    var removeTitle: String?
    var onRemove: (() -> Void)?
    let action: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var stored: [Video]

    init(
        _ video: VideoInfo,
        width: CGFloat? = 248,
        subtitle: String? = nil,
        removeTitle: String? = nil,
        onRemove: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) {
        self.video = video
        self.width = width
        self.subtitle = subtitle
        self.removeTitle = removeTitle
        self.onRemove = onRemove
        self.action = action
        let slug = video.slug
        _stored = Query(filter: #Predicate<Video> { $0.slug == slug })
    }

    var body: some View {
        let record = stored.first
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 10) {
                    Thumbnail(url: video.thumbnailURL)
                        .overlay(alignment: .topLeading) { cornerBadge }
                        .overlay(alignment: .bottomLeading) { textBadge(record) }
                        .overlay(alignment: .bottom) { progressBar(record) }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(video.displayTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(subtitle ?? video.cardSubtitle)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                    }
                    .padding(.trailing, onRemove == nil ? 0 : 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                VideoStore.toggleFavourite(video, in: context)
            } label: {
                let isFavourite = record?.isFavourite ?? false
                Image(systemName: isFavourite ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFavourite ? Theme.accent : Theme.text)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel((record?.isFavourite ?? false) ? "Remove from favourites" : "Add to favourites")
        }
        .overlay(alignment: .bottomTrailing) {
            if let onRemove {
                Menu {
                    Button(role: .destructive, action: onRemove) {
                        Label(removeTitle ?? "Remove", systemImage: "minus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More options for \(video.displayTitle)")
            }
        }
        .frame(width: width)
    }

    /// Top left: on this iPad, or locked.
    @ViewBuilder
    private var cornerBadge: some View {
        if app.downloads.isDownloaded(video.slug) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 30, height: 30)
                .background(Theme.accent, in: Circle())
                .padding(8)
                .accessibilityLabel("Downloaded")
        } else if !video.accessible, !video.isUpcoming {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.6), in: Circle())
                .padding(8)
                .accessibilityLabel("Not in your subscription")
        }
    }

    /// Bottom left: when a live session is, or that she has watched it.
    @ViewBuilder
    private func textBadge(_ record: Video?) -> some View {
        if let live = video.liveBadge {
            chip(live)
        } else if record?.finished == true {
            chip("Watched")
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.leading, 8)
            .padding(.bottom, 12)
    }

    @ViewBuilder
    private func progressBar(_ record: Video?) -> some View {
        if let record, record.isInProgress, let progress = record.progress {
            ProgressLine(fraction: progress, height: 6)
        }
    }
}

/// A thin ochre bar over a dark track.
struct ProgressLine: View {
    let fraction: Double
    var height: CGFloat = 6
    var track: Color = Color.black.opacity(0.6)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle().fill(Theme.accent)
                    .frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
    }
}

/// A heading with an optional note beside it and "See all" at the end.
struct SectionHeader: View {
    let title: String
    var note: String?
    var actionTitle = "See all"
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text)
            if let note {
                Text(note)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 12)
            if let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .frame(minHeight: 44)
            }
        }
        .frame(minHeight: 44)
    }
}

/// A heading and one row that scrolls sideways, the pattern most of the app is made of.
struct RowSection<Content: View>: View {
    let title: String
    var note: String?
    var seeAll: (() -> Void)?
    let content: Content

    init(_ title: String, note: String? = nil, seeAll: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.note = note
        self.seeAll = seeAll
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, note: note, action: seeAll)
                .padding(.horizontal, Theme.gutter)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 18) {
                    content
                }
                .padding(.horizontal, Theme.gutter)
            }
        }
    }
}

/// The grid used wherever a whole list of videos is shown.
struct VideoGrid<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 230), spacing: 20, alignment: .top)],
            alignment: .leading,
            spacing: 26
        ) {
            content
        }
        .padding(.horizontal, Theme.gutter)
    }
}

/// A message with a button, for when something needs her attention (sign in, no connection).
struct NoticeBar: View {
    let systemImage: String
    let text: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(buttonTitle, action: action)
                .buttonStyle(PillButtonStyle(kind: .primary, height: 48, fontSize: 16))
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Theme.gutter)
    }
}

/// A bookmark as a row: the picture, her note, which video, and the time.
struct BookmarkRow: View {
    let mark: Bookmark
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Thumbnail(url: mark.video?.info.thumbnailURL, cornerRadius: 8)
                    .frame(width: 128)
                VStack(alignment: .leading, spacing: 4) {
                    Text(mark.note.isEmpty ? "Bookmark" : mark.note)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(mark.video?.info.displayTitle ?? "")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(Timecode.string(mark.time))
                    .font(.system(size: 18, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)
            .padding(.trailing, 18)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
