import SwiftData
import SwiftUI
import UIKit

/// The full-screen player: big controls, AirPlay, bookmarks, and her place remembered.
struct PlayerScreen: View {
    let request: PlayRequest

    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var player = PlayerModel()
    @State private var video: Video?
    @State private var resumedFrom: Double?
    @State private var lastSaved = Date.distantPast
    @State private var editingBookmark: Bookmark?
    @State private var noteText = ""
    @State private var toast: String?

    private static let speeds: [Double] = [0.5, 0.75, 1, 1.25, 1.5]

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            let maxVideoHeight = geo.size.height * (wide ? 0.45 : 0.36)
            Group {
                if wide {
                    HStack(alignment: .top, spacing: 28) {
                        controls(maxVideoHeight: maxVideoHeight)
                        bookmarksPanel
                            .frame(width: min(360, geo.size.width * 0.3))
                    }
                } else {
                    VStack(spacing: 20) {
                        controls(maxVideoHeight: maxVideoHeight)
                        bookmarksPanel
                    }
                }
            }
            .padding(28)
        }
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.headline)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .alert(noteTitle, isPresented: isEditingNote) {
            TextField("e.g. mixing the shadow colour", text: $noteText)
            Button("Save") { saveNote() }
            Button("Cancel", role: .cancel) { editingBookmark = nil }
        }
        .task { await start() }
        .onDisappear { finish() }
    }

    // MARK: - Layout

    private func controls(maxVideoHeight: CGFloat) -> some View {
        VStack(spacing: 16) {
            header
            videoArea
                .frame(maxHeight: maxVideoHeight)
            timeline
            transport
            secondaryRow
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Label("Done", systemImage: "chevron.down")
                    .font(.title3.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.video.title)
                    .font(.title2.bold())
                    .lineLimit(1)
                if !request.video.tutor.isEmpty {
                    Text(request.video.tutor)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if request.isOffline {
                Label("On this iPad", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                DownloadButton(video: request.video, streamURL: request.streamURL)
            }

            AirPlayButton()
                .frame(width: 56, height: 56)
                .accessibilityLabel("Play on the TV")
        }
    }

    private var videoArea: some View {
        ZStack {
            Color.black
            VideoSurface(player: player.player)
            if player.isExternal {
                VStack(spacing: 12) {
                    Image(systemName: "appletv.fill")
                        .font(.system(size: 54))
                    Text("Playing on the TV")
                        .font(.title3.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if !player.isReady {
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { player.togglePlay() }
        .overlay(alignment: .bottom) {
            if let resumedFrom {
                HStack(spacing: 14) {
                    Text("Resumed from \(Timecode.string(resumedFrom))")
                        .font(.headline)
                    Button("Start over") {
                        player.seek(to: 0)
                        withAnimation { self.resumedFrom = nil }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
    }

    private var timeline: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(get: { player.currentTime }, set: { player.scrub(to: $0) }),
                in: 0...max(player.duration, 1),
                onEditingChanged: { editing in player.setScrubbing(editing) }
            )
            .overlay { bookmarkTicks.allowsHitTesting(false) }
            .accessibilityLabel("Position")

            HStack {
                Text(Timecode.string(player.currentTime))
                Spacer()
                Text("-" + Timecode.string(max(0, player.duration - player.currentTime)))
            }
            .font(.headline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var bookmarkTicks: some View {
        GeometryReader { geo in
            ForEach(video?.sortedBookmarks ?? []) { mark in
                Capsule()
                    .fill(Color.orange)
                    .frame(width: 4, height: 18)
                    .position(x: tickPosition(mark.time, width: geo.size.width), y: geo.size.height / 2)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 22) {
            RoundControl(systemImage: "gobackward.30", label: "Back 30 seconds") { player.skip(by: -30) }
            RoundControl(systemImage: "gobackward.10", label: "Back 10 seconds") { player.skip(by: -10) }
            Button {
                player.togglePlay()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 108, height: 108)
                    .background(Color.accentColor, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            RoundControl(systemImage: "goforward.10", label: "Forward 10 seconds") { player.skip(by: 10) }
            RoundControl(systemImage: "goforward.30", label: "Forward 30 seconds") { player.skip(by: 30) }
        }
    }

    private var secondaryRow: some View {
        HStack(spacing: 16) {
            Menu {
                ForEach(Self.speeds, id: \.self) { speed in
                    Button {
                        player.setRate(Float(speed))
                    } label: {
                        if Float(speed) == player.rate {
                            Label(speedLabel(speed), systemImage: "checkmark")
                        } else {
                            Text(speedLabel(speed))
                        }
                    }
                }
            } label: {
                Label("Speed \(speedLabel(Double(player.rate)))", systemImage: "speedometer")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }

            Spacer()

            Button {
                addBookmark()
            } label: {
                Label("Bookmark this moment", systemImage: "bookmark.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(video == nil)
        }
    }

    private var bookmarksPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bookmarks")
                .font(.title2.bold())
            let marks = video?.sortedBookmarks ?? []
            if marks.isEmpty {
                Text("Tap “Bookmark this moment” to mark a point you want to come back to.")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(marks) { mark in
                        BookmarkRow(
                            mark: mark,
                            isCurrent: abs(mark.time - player.currentTime) < 2,
                            onJump: { player.seek(to: mark.time) },
                            onEditNote: {
                                noteText = mark.note
                                editingBookmark = mark
                            }
                        )
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(marks[index]) }
                        try? context.save()
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Behaviour

    private func start() async {
        let stored = VideoStore.upsert(request.video, in: context)
        stored.lastWatched = Date.now
        video = stored

        var startAt: Double = 0
        let midway = stored.knownDuration == 0 || stored.lastPosition < stored.knownDuration - 30
        if !stored.finished, stored.lastPosition > 15, midway {
            startAt = stored.lastPosition
        }

        UIApplication.shared.isIdleTimerDisabled = true
        let cookies = await app.web.siteCookies()
        player.onProgress = { time, duration in
            recordProgress(time: time, duration: duration)
        }
        player.load(
            url: request.streamURL,
            cookies: cookies,
            title: request.video.title,
            artist: request.video.tutor,
            artworkURL: request.video.thumbnailURL,
            startAt: startAt
        )
        try? context.save()

        if startAt > 0 {
            resumedFrom = startAt
            try? await Task.sleep(for: .seconds(8))
            withAnimation { resumedFrom = nil }
        }
    }

    private func finish() {
        player.onProgress = nil
        if player.duration > 0 {
            recordProgress(time: player.currentTime, duration: player.duration)
        }
        player.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        try? context.save()
    }

    private func recordProgress(time: Double, duration: Double) {
        guard let video, duration > 0 else { return }
        video.knownDuration = duration
        if time > duration - 20 {
            video.lastPosition = 0
            video.finished = true
        } else if time > 5 {
            video.lastPosition = time
            video.finished = false
        }
        if Date.now.timeIntervalSince(lastSaved) > 10 {
            lastSaved = Date.now
            try? context.save()
        }
    }

    private func addBookmark() {
        guard let video else { return }
        let mark = Bookmark(time: player.currentTime)
        context.insert(mark)
        mark.video = video
        try? context.save()
        showToast("Bookmarked at \(Timecode.string(mark.time))")
    }

    private var isEditingNote: Binding<Bool> {
        Binding(get: { editingBookmark != nil }, set: { if !$0 { editingBookmark = nil } })
    }

    private var noteTitle: String {
        guard let editingBookmark else { return "Note" }
        return "Note at \(Timecode.string(editingBookmark.time))"
    }

    private func saveNote() {
        editingBookmark?.note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        editingBookmark = nil
        try? context.save()
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == text {
                withAnimation { toast = nil }
            }
        }
    }

    private func tickPosition(_ time: Double, width: CGFloat) -> CGFloat {
        guard player.duration > 0 else { return 0 }
        let inset: CGFloat = 14
        return inset + (width - inset * 2) * CGFloat(min(1, time / player.duration))
    }

    private func speedLabel(_ speed: Double) -> String {
        "\(speed.formatted())×"
    }
}
