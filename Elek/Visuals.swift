import SwiftUI

// MARK: - Dotted mesh

/// A grid of small dots (the "dotted mesh" texture). `fadeFromCenter` makes dots
/// fainter toward the center (used faintly behind the hero); otherwise they fade
/// slightly toward the edges (used to fill the header icon).
struct DottedMesh: View {
    var color: Color
    var spacing: CGFloat = 10
    var dotRadius: CGFloat = 1.3
    var fadeFromCenter: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxD = max(1, hypot(size.width / 2, size.height / 2))
            var y = spacing / 2
            while y < size.height {
                var x = spacing / 2
                while x < size.width {
                    let d = Double(hypot(x - center.x, y - center.y) / maxD)
                    let op = fadeFromCenter ? d : (1 - d * 0.35)
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                      width: dotRadius * 2, height: dotRadius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(max(0, min(1, op)))))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

// MARK: - Elek mark

/// The Elek glyph: a stylised sieve/strainer — an arc (dome) above a vertical
/// stroke.
struct ElekMark: View {
    var color: Color
    var lineWidth: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let r = w * 0.32
            let cy = h * 0.42
            Path { p in
                // Dome arc, opening downward.
                p.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                         startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                // Vertical handle from the dome's centre downward.
                p.move(to: CGPoint(x: cx, y: cy))
                p.addLine(to: CGPoint(x: cx, y: h * 0.84))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Hero

/// The 236pt circular protection control. Tapping it toggles protection (or, when
/// pending, opens Settings so the user can finish enabling it).
struct HeroView: View {
    let isOn: Bool
    let isBusy: Bool
    var isPending: Bool = false
    let palette: Palette
    var action: () -> Void

    @State private var breathe = false

    private let faceSize: CGFloat = 236
    private let meshSize: CGFloat = 300
    private let amber = Color(hex: 0xE0A030)

    /// The colour that expresses the current state on the face.
    private var stateTint: Color {
        if isOn { return palette.accent }
        if isPending { return amber }
        return palette.secondary
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Faint dotted-mesh texture, faded toward the centre.
                DottedMesh(color: palette.accent.opacity(0.16), spacing: 13,
                           dotRadius: 1.4, fadeFromCenter: true)
                    .frame(width: meshSize, height: meshSize)
                    .mask(Circle())

                // Outer breathing glow — only visible when active.
                Circle()
                    .fill(RadialGradient(
                        colors: [palette.accent.opacity(0.55), palette.accent.opacity(0.0)],
                        center: .center, startRadius: 30, endRadius: 165))
                    .frame(width: meshSize, height: meshSize)
                    .scaleEffect(breathe ? 1.08 : 0.9)
                    .opacity(isOn ? 1 : 0)
                    .animation(.easeInOut(duration: 2.3).repeatForever(autoreverses: true), value: breathe)
                    .animation(.easeOut(duration: 0.45), value: isOn)

                // Raised face.
                Circle()
                    .fill(LinearGradient(colors: [palette.faceTop, palette.faceBottom],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: faceSize, height: faceSize)
                    .overlay(  // accent ring border
                        Circle().strokeBorder(stateTint.opacity(isOn ? 0.9 : (isPending ? 0.7 : 0.28)),
                                              lineWidth: 2))
                    .overlay(  // faint inner "sieve" ring
                        Circle().strokeBorder(palette.secondary.opacity(0.18), lineWidth: 1)
                            .padding(20))
                    .shadow(color: isOn ? palette.accent.opacity(0.33) : .black.opacity(0.12),
                            radius: isOn ? 26 : 14, x: 0, y: 8)

                // Centered glyph.
                ElekMark(color: stateTint)
                    .frame(width: 92, height: 92)

                if isBusy {
                    ProgressView().tint(palette.accent)
                        .scaleEffect(1.2)
                }
            }
            .frame(width: meshSize, height: meshSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .onAppear { breathe = isOn }
        .onChange(of: isOn) { newValue in breathe = newValue }
    }
}

// MARK: - Status

struct StatusView: View {
    let isOn: Bool
    var isPending: Bool = false
    let palette: Palette

    private var dotColor: Color {
        if isOn { return palette.accent }
        if isPending { return Color(hex: 0xE0A030) }
        return palette.secondary
    }

    private var title: String {
        if isOn { return "Protection active" }
        if isPending { return "Almost there" }
        return "Protection off"
    }

    private var subtitle: String {
        if isOn { return "Ads and trackers are filtered for every app." }
        if isPending { return "Enable Elek in Settings to finish turning on." }
        return "Filtering is paused. Tap to turn on."
    }

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(dotColor)
                .frame(width: 9, height: 9)
                .shadow(color: isOn ? palette.accent.opacity(0.8) : .clear, radius: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isOn)
        .animation(.easeInOut(duration: 0.25), value: isPending)
    }
}

// MARK: - Activation banner

/// Shown when the DNS configuration is installed but the user hasn't switched it
/// on yet. iOS doesn't let the app enable it directly, so we guide them.
struct ActivationBanner: View {
    let palette: Palette
    var openSettings: () -> Void

    private let amber = Color(hex: 0xE0A030)

    var body: some View {
        VStack(spacing: 12) {
            Text("One last step — just once")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.text)
            Text("iOS only lets you switch Elek on yourself. Open Settings, then:\n1.  General › VPN & Device Management\n2.  Tap DNS, then choose Elek\n\nAfter this it stays on automatically.")
                .font(.system(size: 13))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(amber, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(amber.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Protection footer

/// A quiet footer line. The app no longer sees DNS queries (the resolver filters
/// and logs nothing), so there's no live count to show — just what protection is
/// in force. Turns accent when active.
struct ProtectionFooter: View {
    let isOn: Bool
    let palette: Palette

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .bold))
            Text("System-wide · encrypted DNS")
                .font(.system(size: 13))
        }
        .foregroundStyle(isOn ? palette.accent : palette.secondary)
        .animation(.easeInOut(duration: 0.3), value: isOn)
    }
}

// MARK: - Header

struct HeaderView: View {
    let palette: Palette

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                // Mini app-icon: accent gradient chip with the white Elek mark.
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x4FB6A0), Color(hex: 0x2E7E6C)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 28, height: 28)
                    .overlay(
                        ElekMark(color: .white, lineWidth: 2.6)
                            .frame(width: 15, height: 15)
                    )
                    .shadow(color: Color(hex: 0x2E7E6C).opacity(0.35), radius: 4, x: 0, y: 2)

                Text("Elek")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.text)
            }

            Spacer()
        }
    }
}
