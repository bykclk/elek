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

/// The 236pt circular protection control. Tapping it toggles protection.
struct HeroView: View {
    let isOn: Bool
    let isBusy: Bool
    let palette: Palette
    var action: () -> Void

    @State private var breathe = false

    private let faceSize: CGFloat = 236
    private let meshSize: CGFloat = 300

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
                        Circle().strokeBorder(palette.accent.opacity(isOn ? 0.9 : 0.28),
                                              lineWidth: 2))
                    .overlay(  // faint inner "sieve" ring
                        Circle().strokeBorder(palette.secondary.opacity(0.18), lineWidth: 1)
                            .padding(20))
                    .shadow(color: isOn ? palette.accent.opacity(0.33) : .black.opacity(0.12),
                            radius: isOn ? 26 : 14, x: 0, y: 8)

                // Centered glyph.
                ElekMark(color: isOn ? palette.accent : palette.secondary)
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
    let palette: Palette

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(isOn ? palette.accent : palette.secondary)
                .frame(width: 9, height: 9)
                .shadow(color: isOn ? palette.accent.opacity(0.8) : .clear, radius: 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(isOn ? "Koruma aktif" : "Koruma kapalı")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(isOn
                     ? "Reklamlar ve izleyiciler cihazında engelleniyor."
                     : "Filtreleme şu an duraklatıldı. Açmak için dokun.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isOn)
    }
}

// MARK: - Live chip

struct LiveChip: View {
    let accent: Color
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
                .scaleEffect(pulse ? 1.0 : 0.55)
                .opacity(pulse ? 1 : 0.4)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            Text("canlı")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(accent)
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Counter block

struct CounterBlock: View {
    let count: Int
    let isOn: Bool
    let palette: Palette

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.secondary.opacity(0.18))
                .frame(height: 1)
                .padding(.bottom, 18)

            Text(count, format: .number.grouping(.automatic).locale(Locale(identifier: "tr_TR")))
                .font(.system(size: 54, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isOn ? palette.accent : palette.secondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: count)

            Text("BUGÜN ENGELLENEN İSTEK")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(palette.secondary)
                .padding(.top, 2)

            if isOn {
                LiveChip(accent: palette.accent)
                    .padding(.top, 10)
                    .transition(.opacity)
            }

            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text("Sistem genelinde · DNS düzeyinde")
                    .font(.system(size: 12))
            }
            .foregroundStyle(palette.secondary)
            .padding(.top, 14)
        }
        .animation(.easeInOut(duration: 0.3), value: isOn)
    }
}

// MARK: - Header

struct HeaderView: View {
    let palette: Palette

    var body: some View {
        HStack {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(palette.accent.opacity(0.14))
                    .frame(width: 22, height: 22)
                    .overlay(
                        DottedMesh(color: palette.accent, spacing: 5, dotRadius: 1.0)
                            .mask(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    )
                Text("Elek")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(palette.text)
            }

            Spacer()

            // Inert in v1.
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.text.opacity(0.8))
                .frame(width: 38, height: 38)
                .background(Circle().fill(palette.text.opacity(0.06)))
        }
    }
}
