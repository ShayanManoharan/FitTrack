import SwiftUI

enum FitTrackStyle {
    static let accent = Color(red: 8 / 255, green: 127 / 255, blue: 120 / 255)
    static let ink = Color(red: 24 / 255, green: 49 / 255, blue: 52 / 255)
    static let muted = Color(red: 105 / 255, green: 128 / 255, blue: 126 / 255)
    static let background = Color(red: 247 / 255, green: 250 / 255, blue: 249 / 255)
    static let pale = Color(red: 227 / 255, green: 244 / 255, blue: 239 / 255)
    static let line = Color(red: 203 / 255, green: 222 / 255, blue: 217 / 255)
    static let detail = Color(red: 243 / 255, green: 248 / 255, blue: 246 / 255)
    static let tabMuted = Color(red: 135 / 255, green: 153 / 255, blue: 151 / 255)
    static let disabled = Color(red: 184 / 255, green: 206 / 255, blue: 202 / 255)
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
            .foregroundStyle(color).background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(FitTrackStyle.line))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    func fitTrackCard() -> some View {
        padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 17))
            .shadow(color: FitTrackStyle.ink.opacity(0.04), radius: 7, y: 3)
    }
    func fitTrackScreen() -> some View {
        foregroundStyle(FitTrackStyle.ink).tint(FitTrackStyle.accent)
            .background(FitTrackStyle.background).preferredColorScheme(.light)
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
