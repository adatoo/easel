import SwiftUI

/// Download / progress / downloaded, for a video whose stream is known.
struct DownloadButton: View {
    let video: VideoInfo
    let streamURL: URL
    @Environment(AppModel.self) private var app
    @State private var confirmDelete = false

    var body: some View {
        let downloads = app.downloads
        Group {
            if downloads.isDownloaded(video.slug) {
                Button {
                    confirmDelete = true
                } label: {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            } else if let progress = downloads.progress(for: video.slug) {
                Button {
                    downloads.cancel(video.slug)
                } label: {
                    HStack(spacing: 10) {
                        ProgressView(value: progress)
                            .progressViewStyle(.circular)
                        Text("\(Int(progress * 100))% · Cancel")
                    }
                }
            } else {
                Button {
                    Task {
                        let cookies = await app.web.siteCookies()
                        downloads.download(video, from: streamURL, cookies: cookies)
                    }
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                }
            }
        }
        .font(.title3.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.large)
        .confirmationDialog("Remove the download?", isPresented: $confirmDelete) {
            Button("Remove from iPad", role: .destructive) { downloads.delete(video.slug) }
        } message: {
            Text("You can still watch it online.")
        }
    }
}
