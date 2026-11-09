import SwiftData
import SwiftUI
import WebKit

/// The Raw Umber website itself, with a big Watch button on any video page Easel can play.
struct WebsiteView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context

    var body: some View {
        let web = app.web
        NavigationStack {
            WebViewContainer(webView: web.webView)
                .ignoresSafeArea(.container, edges: .bottom)
                .overlay(alignment: .bottom) {
                    if let video = web.pageVideo, web.streamURL != nil {
                        WatchBar(resumeAt: resumePosition(for: video)) {
                            app.watchCurrentPage()
                        }
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.35), value: web.streamURL)
                .navigationTitle(web.pageVideo?.title ?? "Raw Umber")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button { web.goBack() } label: { Image(systemName: "chevron.backward") }
                            .disabled(!web.canGoBack)
                            .accessibilityLabel("Back")
                        Button { web.goForward() } label: { Image(systemName: "chevron.forward") }
                            .disabled(!web.canGoForward)
                            .accessibilityLabel("Forward")
                        Button { web.goHome() } label: { Image(systemName: "house") }
                            .accessibilityLabel("Video playlists")
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let video = web.pageVideo, let stream = web.streamURL {
                            DownloadButton(video: video, streamURL: stream)
                        }
                        if let video = web.pageVideo {
                            FavouriteToggle(video: video)
                        }
                        if web.isLoading {
                            ProgressView()
                        } else {
                            Button { web.reload() } label: { Image(systemName: "arrow.clockwise") }
                                .accessibilityLabel("Reload")
                        }
                    }
                }
        }
    }

    private func resumePosition(for video: VideoInfo) -> Double? {
        guard let stored = VideoStore.find(video, in: context), !stored.finished, stored.lastPosition > 15 else {
            return nil
        }
        return stored.lastPosition
    }
}

private struct WatchBar: View {
    let resumeAt: Double?
    let onWatch: () -> Void

    var body: some View {
        Button(action: onWatch) {
            HStack(spacing: 16) {
                Image(systemName: "play.fill")
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resumeAt.map { "Resume from \(Timecode.string($0))" } ?? "Watch in Easel")
                        .font(.title3.bold())
                    Text("Big controls · AirPlay to the TV")
                        .font(.subheadline)
                        .opacity(0.85)
                }
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 18)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
