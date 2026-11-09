import AVFoundation
import SwiftData
import SwiftUI

@main
struct EaselApp: App {
    private let container: ModelContainer
    @State private var app: AppModel

    init() {
        // Long-form video, so AirPlay sends the stream itself to the Apple TV and it keeps
        // playing when the iPad locks.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .moviePlayback, policy: .longFormVideo, options: []
        )
        do {
            let container = try ModelContainer(for: Video.self, Bookmark.self)
            self.container = container
            _app = State(initialValue: AppModel(context: container.mainContext))
        } catch {
            fatalError("Easel couldn't open its library: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
        .modelContainer(container)
    }
}
