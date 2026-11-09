import SwiftUI
import WebKit

/// The whole app: three tabs with a bar along the bottom, the mini player above it while
/// something is loaded, and the full player over everything when it's open.
struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        ZStack {
            // The two web views that talk to the site. They have to be in the window to run
            // normally, but sit behind everything.
            BackgroundWebViews()
            Theme.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    TabPage(tab: .home) {
                        NavigationStack(path: $app.homePath) {
                            HomeView()
                                .navigationDestination(for: Route.self) { RouteView(route: $0) }
                        }
                    }
                    TabPage(tab: .search) {
                        NavigationStack(path: $app.searchPath) {
                            SearchView()
                                .navigationDestination(for: Route.self) { RouteView(route: $0) }
                        }
                    }
                    TabPage(tab: .myEasel) {
                        NavigationStack(path: $app.myEaselPath) {
                            MyEaselView()
                                .navigationDestination(for: Route.self) { RouteView(route: $0) }
                        }
                    }
                }
                if app.nowPlaying != nil, !app.playerExpanded {
                    MiniPlayer()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                TabBar()
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)

            if app.playerExpanded, let playing = app.nowPlaying {
                PlayerOverlay(playing: playing)
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
        .animation(.spring(duration: 0.35), value: app.playerExpanded)
        .animation(.spring(duration: 0.35), value: app.nowPlaying?.id)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .statusBarHidden(app.playerExpanded && !app.player.isExternal)
        .sheet(isPresented: $app.showsAccount) {
            AccountSheet()
                .environment(app)
        }
        .fullScreenCover(item: $app.website, onDismiss: { app.websiteClosed() }) { request in
            WebsiteSheet(request: request)
        }
        .alert(
            "That didn't work",
            isPresented: Binding(get: { app.problem != nil }, set: { if !$0 { app.problem = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(app.problem ?? "")
        }
    }
}

/// A destination pushed inside a tab.
struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .video(let video):
            VideoDetailView(video: video)
        case .playlist(let playlist):
            PlaylistView(playlist: playlist)
        case .shelf(let shelf):
            ShelfView(shelf: shelf)
        }
    }
}

/// Keeps every tab alive so each remembers where she was, and shows the selected one.
private struct TabPage<Content: View>: View {
    let tab: AppModel.Tab
    @ViewBuilder var content: () -> Content
    @Environment(AppModel.self) private var app

    var body: some View {
        let selected = app.tab == tab
        content()
            .opacity(selected ? 1 : 0)
            .allowsHitTesting(selected)
            .accessibilityHidden(!selected)
    }
}

private struct TabBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 40) {
            item(.home, "Home", "house")
            item(.search, "Search", "magnifyingglass")
            item(.myEasel, "My Easel", "paintpalette")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(Theme.bar.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Theme.line.opacity(0.6).frame(height: 1)
        }
    }

    private func item(_ tab: AppModel.Tab, _ title: String, _ icon: String) -> some View {
        let selected = app.tab == tab
        return Button {
            app.select(tab)
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 24)
                .frame(height: 52)
                .foregroundStyle(selected ? Theme.accent : Theme.secondary)
                .background(selected ? Theme.raised : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct BackgroundWebViews: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            WebViewHost(webView: app.api.webView)
            WebViewHost(webView: app.resolver.webView)
            AirPlayPickerHost().frame(width: 44, height: 44)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Puts an existing WKWebView into the view hierarchy.
struct WebViewHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
