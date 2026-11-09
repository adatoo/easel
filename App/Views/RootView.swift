import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            LibraryView()
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }
                .tag(AppModel.Tab.library)
            FavouritesView()
                .tabItem { Label("Favourites", systemImage: "heart") }
                .tag(AppModel.Tab.favourites)
            ContinueView()
                .tabItem { Label("Continue", systemImage: "play.circle") }
                .tag(AppModel.Tab.continueWatching)
            DownloadsView()
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }
                .tag(AppModel.Tab.downloads)
            WebsiteView()
                .tabItem { Label("Website", systemImage: "globe") }
                .tag(AppModel.Tab.website)
        }
        .fullScreenCover(item: $app.playRequest, onDismiss: { app.playerClosed() }) { request in
            PlayerScreen(request: request)
                .environment(app)
                .modelContext(context)
        }
    }
}
