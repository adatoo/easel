import AVFoundation
import AVKit
import SwiftUI

/// The system AirPlay button; it lists the Apple TV and shows when it's in use.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.prioritizesVideoDevices = true
        view.activeTintColor = .systemOrange
        view.tintColor = .label
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

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

/// A large round transport button.
struct RoundControl: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .frame(width: 76, height: 76)
                .background(Color.secondary.opacity(0.15), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One bookmark in the list: tap the time to jump there, the pencil to add a note.
struct BookmarkRow: View {
    let mark: Bookmark
    let isCurrent: Bool
    let onJump: () -> Void
    let onEditNote: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onJump) {
                HStack(spacing: 12) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(Color.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Timecode.string(mark.time))
                            .font(.title3.monospacedDigit().weight(.semibold))
                        if !mark.note.isEmpty {
                            Text(mark.note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jump to \(Timecode.string(mark.time))")

            Button(action: onEditNote) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(mark.note.isEmpty ? "Add a note" : "Edit note")
        }
        .padding(.vertical, 4)
        .listRowBackground(isCurrent ? Color.orange.opacity(0.14) : Color.clear)
    }
}
