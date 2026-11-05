import SwiftUI

enum FitTrackStyle {
    static let accent = Color(red: 8 / 255, green: 127 / 255, blue: 120 / 255)
    static let ink = adaptive(0x183134, 0xe4f1ee)
    static let muted = adaptive(0x69807e, 0xa6bdb7)
    static let background = adaptive(0xf7faf9, 0x111d1c)
    static let pale = adaptive(0xe3f4ef, 0x203c36)
    static let line = adaptive(0xcbded9, 0x3b514b)
    static let detail = adaptive(0xf3f8f6, 0x1a2a26)
    static let tabMuted = adaptive(0x879997, 0xa2b5b0)
    static let disabled = adaptive(0xb8ceca, 0x49615a)
    static let surface = adaptive(0xffffff, 0x1c2d29)

    private static func adaptive(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Double((hex >> 16) & 255) / 255,
                           green: Double((hex >> 8) & 255) / 255,
                           blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    static func colorScheme(_ appearance: String) -> ColorScheme? {
        switch appearance { case "Light": .light; case "Dark": .dark; default: nil }
    }

}

struct FitTrackPrimary: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 48
    var radius: CGFloat = 12
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(.white).background(isEnabled ? FitTrackStyle.accent : FitTrackStyle.disabled)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct FitTrackOutline: ButtonStyle {
    var height: CGFloat = 44
    var color: Color = FitTrackStyle.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(color).background(FitTrackStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(FitTrackStyle.line))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    func fitTrackCard() -> some View {
        padding(16).background(FitTrackStyle.surface).clipShape(RoundedRectangle(cornerRadius: 17))
            .shadow(color: FitTrackStyle.ink.opacity(0.04), radius: 7, y: 3)
    }
    func fitTrackScreen() -> some View {
        foregroundStyle(FitTrackStyle.ink).tint(FitTrackStyle.accent)
            .background(FitTrackStyle.background)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .heavy)).tracking(1)
            .foregroundStyle(FitTrackStyle.accent)
    }
}

struct StatusPill: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .bold))
            .foregroundStyle(FitTrackStyle.accent).padding(.horizontal, 9).padding(.vertical, 6)
            .background(FitTrackStyle.pale).clipShape(Capsule())
    }
}
