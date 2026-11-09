import SwiftUI

/// Easel's look: a charcoal ground, paper-white text and one ochre accent (the sun in the icon).
enum Theme {
    static let ground = Color(hex: 0x141211)
    static let bar = Color(hex: 0x1A1716)
    static let surface = Color(hex: 0x1F1C1A)
    static let raised = Color(hex: 0x2A2623)
    static let line = Color(hex: 0x3A3531)
    static let text = Color(hex: 0xF3EFE8)
    static let secondary = Color(hex: 0xB3ABA1)
    static let accent = Color(hex: 0xE4A03A)
    static let onAccent = Color(hex: 0x1B1408)

    /// The side margin of every screen.
    static let gutter: CGFloat = 40
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// The app's buttons: a filled ochre one for the main action, grey for the rest.
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case primary, secondary, outline
    }

    var kind: Kind = .secondary
    var height: CGFloat = 52
    var fontSize: CGFloat = 17

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: kind == .primary ? .bold : .semibold))
            .lineLimit(1)
            .padding(.horizontal, height * 0.4)
            .frame(height: height)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .overlay {
                if kind == .outline {
                    Capsule().strokeBorder(Theme.accent, lineWidth: 1.5)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.onAccent
        case .secondary: return Theme.text
        case .outline: return Theme.accent
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return Theme.accent
        case .secondary: return Theme.raised
        case .outline: return Color.clear
        }
    }
}

/// A round button holding one icon.
struct CircleButtonStyle: ButtonStyle {
    var size: CGFloat = 52
    var fill: Color = Theme.raised
    var foreground: Color = Theme.text

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Circle())
    }
}

extension View {
    /// The small capitals line above a title.
    func eyebrow() -> some View {
        font(.system(size: 13, weight: .bold))
            .tracking(1)
            .foregroundStyle(Theme.accent)
    }
}
