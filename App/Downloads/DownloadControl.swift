import SwiftUI

/// Download, its progress, or "Downloaded", for one video. Either a labelled pill or just an icon.
struct DownloadControl: View {
    enum Style {
        case pill, icon
    }

    let video: VideoInfo
    var seriesSlug: String?
    var style: Style = .pill

    @Environment(AppModel.self) private var app
    @State private var confirmRemove = false

    private enum Phase {
        case idle, preparing, downloading(Double), done
    }

    private var phase: Phase {
        if app.downloads.isDownloaded(video.slug) { return .done }
        if let progress = app.downloads.progress(for: video.slug) { return .downloading(progress) }
        if app.preparingDownloads.contains(video.slug) { return .preparing }
        return .idle
    }

    var body: some View {
        Button(action: tapped) {
            switch style {
            case .pill: pillLabel
            case .icon: iconLabel
            }
        }
        .buttonStyle(.plain)
        .animation(nil, value: app.downloads.progress(for: video.slug))
        .confirmationDialog("Remove the download?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove from iPad", role: .destructive) { app.downloads.delete(video.slug) }
        } message: {
            Text("You can still watch it online.")
        }
        .accessibilityLabel(accessibilityText)
    }

    private func tapped() {
        switch phase {
        case .idle: app.download(video, seriesSlug: seriesSlug)
        case .preparing: break
        case .downloading: app.downloads.cancel(video.slug)
        case .done: confirmRemove = true
        }
    }

    private var accessibilityText: String {
        switch phase {
        case .idle: return "Download"
        case .preparing: return "Getting ready to download"
        case .downloading(let progress): return "Downloading, \(Int(progress * 100)) percent. Cancel"
        case .done: return "Downloaded. Remove download"
        }
    }

    /// One fixed width, so the button doesn't change size as it counts up.
    private var pillLabel: some View {
        HStack(spacing: 10) {
            switch phase {
            case .idle:
                Image(systemName: "arrow.down.to.line")
                Text("Download")
            case .preparing:
                ProgressView().controlSize(.small)
                Text("Starting…")
            case .downloading(let progress):
                ProgressRing(fraction: progress, size: 20)
                Text("\(Int(progress * 100))% · Cancel").monospacedDigit()
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                Text("Downloaded")
            }
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Theme.text)
        .lineLimit(1)
        .frame(width: 168, height: 52)
        .background(Theme.raised, in: Capsule())
        .contentShape(Capsule())
    }

    private var iconLabel: some View {
        ZStack {
            switch phase {
            case .idle:
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            case .preparing:
                ProgressView().controlSize(.small)
            case .downloading(let progress):
                ProgressRing(fraction: progress, size: 28)
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(width: 52, height: 52)
        .contentShape(Rectangle())
    }
}

/// A small ring that fills as a download progresses.
struct ProgressRing: View {
    let fraction: Double
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(1, max(0.02, fraction)))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}
