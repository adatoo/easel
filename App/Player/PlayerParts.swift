import AVFoundation
import AVKit
import SwiftUI

/// The video itself, with no system controls on top.
struct VideoSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// The system's AirPlay picker, opened from Easel's own big button. The picker view itself is
/// kept in the window (it has to be) but is invisible.
@MainActor
final class AirPlayPicker {
    static let shared = AirPlayPicker()

    let view: AVRoutePickerView = {
        let picker = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.prioritizesVideoDevices = true
        picker.alpha = 0.02
        return picker
    }()

    func present() {
        for case let button as UIButton in view.subviews {
            button.sendActions(for: .touchUpInside)
            return
        }
    }
}

struct AirPlayPickerHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        container.isUserInteractionEnabled = false
        container.addSubview(AirPlayPicker.shared.view)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if AirPlayPicker.shared.view.superview !== uiView {
            uiView.addSubview(AirPlayPicker.shared.view)
        }
    }
}

/// The scrubber: a thick bar with white ticks at her bookmarks. Drag anywhere along it.
struct Scrubber: View {
    let player: PlayerModel
    let bookmarks: [Double]
    var barHeight: CGFloat = 8
    var knob: CGFloat = 28
    var track: Color = Color.white.opacity(0.32)

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let duration = max(player.duration, 1)
            let fraction = min(1, max(0, player.currentTime / duration))
            ZStack(alignment: .leading) {
                Capsule().fill(track).frame(height: barHeight)
                Capsule().fill(Theme.accent).frame(width: width * fraction, height: barHeight)
                ForEach(bookmarks, id: \.self) { time in
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Theme.text)
                        .frame(width: 5, height: barHeight + 14)
                        .shadow(color: .black.opacity(0.6), radius: 1)
                        .offset(x: width * min(1, time / duration) - 2.5)
                }
                Circle()
                    .fill(Theme.text)
                    .frame(
                        width: player.isScrubbing ? knob * 1.25 : knob,
                        height: player.isScrubbing ? knob * 1.25 : knob
                    )
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                    .offset(x: width * fraction - (player.isScrubbing ? knob * 0.625 : knob / 2))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        player.setScrubbing(true)
                        player.scrub(to: min(1, max(0, value.location.x / width)) * player.duration)
                    }
                    .onEnded { _ in
                        player.setScrubbing(false)
                    }
            )
        }
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel("Position")
        .accessibilityValue(
            "\(Timecode.string(player.currentTime)) of \(Timecode.string(player.duration))"
        )
        .accessibilityAdjustableAction { direction in
            player.skip(by: direction == .increment ? 10 : -10)
        }
    }
}

/// A round "go back / forward N seconds" button.
struct SkipButton: View {
    let seconds: Int
    var size: CGFloat = 96
    var fill: Color = Color.black.opacity(0.55)
    let action: () -> Void

    var body: some View {
        let forward = seconds > 0
        let amount = abs(seconds)
        Button(action: action) {
            Image(systemName: forward ? "goforward.\(amount)" : "gobackward.\(amount)")
        }
        .buttonStyle(CircleButtonStyle(size: size, fill: fill))
        .accessibilityLabel(forward ? "Forward \(amount) seconds" : "Back \(amount) seconds")
    }
}

/// The big play/pause button.
struct PlayPauseButton: View {
    let player: PlayerModel
    var size: CGFloat = 128

    var body: some View {
        Button {
            player.togglePlay()
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: size, height: size)
                .background(Theme.accent, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
    }
}

/// Playback speed, as a menu.
struct SpeedMenu: View {
    let player: PlayerModel
    var fill: Color = Theme.raised

    private static let speeds: [Float] = [0.5, 0.75, 1, 1.25, 1.5]

    var body: some View {
        Menu {
            ForEach(Self.speeds, id: \.self) { speed in
                Button {
                    player.setRate(speed)
                } label: {
                    if speed == player.rate {
                        Label(Self.label(speed), systemImage: "checkmark")
                    } else {
                        Text(Self.label(speed))
                    }
                }
            }
        } label: {
            Text("Speed \(Self.label(player.rate))")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 20)
                .frame(height: 52)
                .background(fill, in: Capsule())
        }
    }

    static func label(_ speed: Float) -> String {
        "\(Double(speed).formatted())×"
    }
}
