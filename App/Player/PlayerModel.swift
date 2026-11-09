import AVFoundation
import MediaPlayer
import Observation
import UIKit

/// Easel's player: an AVPlayer that AirPlays the stream to the Apple TV, with the iPad as the
/// remote. The Siri Remote and the lock screen controls drive it too. It belongs to the app, not
/// to a screen, so a video keeps playing while she browses.
@MainActor
@Observable
final class PlayerModel {
    let player = AVPlayer()

    private(set) var isPlaying = false
    private(set) var isReady = false
    private(set) var failed = false
    /// True while the video is playing on the Apple TV rather than on the iPad.
    private(set) var isExternal = false
    private(set) var duration: Double = 0
    private(set) var currentTime: Double = 0
    private(set) var rate: Float = 1
    private(set) var isScrubbing = false
    /// Whether the stream carries subtitles she can switch on.
    private(set) var hasSubtitles = false
    private(set) var subtitlesOn = false

    /// Called about twice a second with (time, duration) while it plays, to save her place.
    @ObservationIgnored var onProgress: ((Double, Double) -> Void)?
    @ObservationIgnored private var pendingStart: Double = 0
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var commandTargets: [(MPRemoteCommand, Any)] = []
    @ObservationIgnored private var nowPlayingTitle = ""
    @ObservationIgnored private var nowPlayingArtist = ""
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    @ObservationIgnored private var subtitleGroup: AVMediaSelectionGroup?

    /// The Apple TV's name while AirPlaying, e.g. "Living Room".
    var routeName: String? {
        AVAudioSession.sharedInstance().currentRoute.outputs.first { $0.portType == .airPlay }?.portName
    }

    func load(url: URL, cookies: [HTTPCookie], title: String, artist: String, artworkURL: URL?, startAt: Double) {
        try? AVAudioSession.sharedInstance().setActive(true)
        nowPlayingTitle = title
        nowPlayingArtist = artist
        artwork = nil
        pendingStart = startAt
        isReady = false
        failed = false
        duration = 0
        currentTime = startAt
        hasSubtitles = false
        subtitlesOn = false
        subtitleGroup = nil

        let asset = AVURLAsset(url: url, options: [AVURLAssetHTTPCookiesKey: cookies])
        let item = AVPlayerItem(asset: asset)
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        player.defaultRate = rate
        player.replaceCurrentItem(with: item)
        observe(item)
        configureRemoteCommands()
        updateNowPlaying()
        if let artworkURL {
            Task { await loadArtwork(from: artworkURL) }
        }
        Task { await loadSubtitles(of: item) }
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlay() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        player.defaultRate = newRate
        if player.rate != 0 { player.rate = newRate }
        updateNowPlaying()
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    func seek(to seconds: Double) {
        let target = max(0, duration > 1 ? min(seconds, duration - 1) : seconds)
        currentTime = target
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor in self?.updateNowPlaying() }
        }
    }

    /// The scrubber: while her finger is down the time follows it; the seek happens on release.
    func setScrubbing(_ scrubbing: Bool) {
        guard isScrubbing != scrubbing else { return }
        isScrubbing = scrubbing
        if !scrubbing { seek(to: currentTime) }
    }

    func scrub(to seconds: Double) {
        currentTime = seconds
        if !isScrubbing { seek(to: seconds) }
    }

    func toggleSubtitles() {
        guard let item = player.currentItem, let group = subtitleGroup, let option = group.options.first else { return }
        subtitlesOn.toggle()
        item.select(subtitlesOn ? option : nil, in: group)
    }

    func stop() {
        player.pause()
        removeObservers()
        removeRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        player.replaceCurrentItem(with: nil)
        isPlaying = false
        isReady = false
        isExternal = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Observing the player

    private func observe(_ item: AVPlayerItem) {
        removeObservers()
        observations = [
            player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
                let playing = player.timeControlStatus != .paused
                Task { @MainActor in self?.setPlaying(playing) }
            },
            player.observe(\.isExternalPlaybackActive, options: [.initial, .new]) { [weak self] player, _ in
                let external = player.isExternalPlaybackActive
                Task { @MainActor in self?.isExternal = external }
            },
            item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                let status = item.status
                let seconds = item.duration.seconds
                Task { @MainActor in self?.itemChanged(status: status, duration: seconds) }
            },
        ]
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time.seconds) }
        }
    }

    private func removeObservers() {
        observations.forEach { $0.invalidate() }
        observations = []
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private func itemChanged(status: AVPlayerItem.Status, duration seconds: Double) {
        if status == .failed {
            failed = true
            return
        }
        if seconds.isFinite, seconds > 0 { duration = seconds }
        guard status == .readyToPlay, !isReady else { return }
        isReady = true
        let start = pendingStart
        pendingStart = 0
        Task {
            if start > 0 {
                _ = await player.seek(to: CMTime(seconds: start, preferredTimescale: 600))
                currentTime = start
            }
            player.play()
            updateNowPlaying()
        }
    }

    private func tick(_ seconds: Double) {
        if duration == 0, let length = player.currentItem?.duration.seconds, length.isFinite, length > 0 {
            duration = length
        }
        guard isReady, !isScrubbing, seconds.isFinite else { return }
        currentTime = seconds
        onProgress?(seconds, duration)
    }

    private func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        updateNowPlaying()
    }

    private func loadSubtitles(of item: AVPlayerItem) async {
        guard let group = try? await item.asset.loadMediaSelectionGroup(for: .legible),
              item === player.currentItem
        else { return }
        subtitleGroup = group
        hasSubtitles = !group.options.isEmpty
    }

    // MARK: - Lock screen, Control Centre and the Siri Remote

    private func configureRemoteCommands() {
        removeRemoteCommands()
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.preferredIntervals = [10]
        add(center.playCommand) { $0.player.play() }
        add(center.pauseCommand) { $0.player.pause() }
        add(center.togglePlayPauseCommand) { $0.togglePlay() }
        add(center.skipForwardCommand) { $0.skip(by: 10) }
        add(center.skipBackwardCommand) { $0.skip(by: -10) }

        let command = center.changePlaybackPositionCommand
        command.isEnabled = true
        let token = command.addTarget { [weak self] event in
            guard let model = self, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor in model.seek(to: position) }
            return .success
        }
        commandTargets.append((command, token))
    }

    private func add(_ command: MPRemoteCommand, _ action: @escaping @Sendable @MainActor (PlayerModel) -> Void) {
        command.isEnabled = true
        let token = command.addTarget { [weak self] _ in
            guard let model = self else { return .commandFailed }
            Task { @MainActor in action(model) }
            return .success
        }
        commandTargets.append((command, token))
    }

    private func removeRemoteCommands() {
        for (command, token) in commandTargets {
            command.removeTarget(token)
        }
        commandTargets = []
    }

    private func updateNowPlaying() {
        guard player.currentItem != nil else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle,
            MPMediaItemPropertyArtist: nowPlayingArtist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(rate),
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
        ]
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(from url: URL) async {
        guard let result = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: result.0)
        else { return }
        artwork = Self.makeArtwork(image)
        updateNowPlaying()
    }

    /// Built outside the main actor: MediaPlayer asks for the image on its own queue.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
