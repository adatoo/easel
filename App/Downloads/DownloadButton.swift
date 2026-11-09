import SwiftUI

/// Download / progress / downloaded, for a video whose stream is known.
struct DownloadButton: View {
    let video: VideoInfo
    let streamURL: URL
    @Environment(AppModel.self) private var app
    @State private var confirmDelete = false

    /// Wide enough for the longest state, so the button keeps its size as it changes.
    private static let labelWidth: CGFloat = 190

    var body: some View {
        let downloads = app.downloads
        Group {
            if downloads.isDownloaded(video.slug) {
                Button {
                    confirmDelete = true
                } label: {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .frame(width: Self.labelWidth)
                }
                .tint(.green)
            } else if let progress = downloads.progress(for: video.slug) {
                Button {
                    downloads.cancel(video.slug)
                } label: {
                    HStack(spacing: 10) {
                        ProgressView(value: progress)
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("\(Int(progress * 100))%")
                            .monospacedDigit()
                            .frame(width: 52, alignment: .trailing)
                        Text("Cancel")
                    }
                    .frame(width: Self.labelWidth)
                }
            } else {
                Button {
                    Task {
                        let cookies = await app.web.siteCookies()
                        downloads.download(video, from: streamURL, cookies: cookies)
                    }
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .frame(width: Self.labelWidth)
                }
            }
        }
        .font(.title3.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.large)
        .lineLimit(1)
        .fixedSize()
        .animation(nil, value: downloads.progress(for: video.slug))
        .confirmationDialog("Remove the download?", isPresented: $confirmDelete) {
            Button("Remove from iPad", role: .destructive) { downloads.delete(video.slug) }
        } message: {
            Text("You can still watch it online.")
        }
    }
}
