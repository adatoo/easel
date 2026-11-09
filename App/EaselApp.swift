import AVFoundation
import SwiftData
import SwiftUI

@main
struct EaselApp: App {
    @State private var app = AppModel()

    init() {
        // Long-form video, so AirPlay sends the stream itself to the Apple TV and it keeps
        // playing when the iPad locks.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .moviePlayback, policy: .longFormVideo, options: []
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
        .modelContainer(for: [Video.self, Bookmark.self])
    }
}
