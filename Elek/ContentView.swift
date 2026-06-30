import SwiftUI

/// Minimal functional screen for steps 1–4. The full Elek design lands in
/// step 5; this just lets us trigger the permission prompt and toggle the
/// proxy on a real device.
struct ContentView: View {
    @EnvironmentObject private var proxy: ProxyManager
    @StateObject private var counter = CounterStore()

    var body: some View {
        VStack(spacing: 24) {
            Text("Elek")
                .font(.system(size: 28, weight: .semibold))

            statusLabel

            counterBlock

            Button {
                Task { await proxy.toggle() }
            } label: {
                Text(buttonTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .disabled(proxy.state == .busy)
            .padding(.horizontal, 32)

            Text("DoH upstream • Binary Fuse blocklist • real counter")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
        .task { counter.start() }
        .onDisappear { counter.stop() }
    }

    private var counterBlock: some View {
        VStack(spacing: 2) {
            Text(counter.count, format: .number.grouping(.automatic).locale(Locale(identifier: "tr_TR")))
                .font(.system(size: 54, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(proxy.isOn ? Color.accentColor : .secondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: counter.count)
            Text("BUGÜN ENGELLENEN İSTEK")
                .font(.caption2)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch proxy.state {
        case .unknown: Label("Yükleniyor…", systemImage: "circle.dotted")
        case .off:     Label("Koruma kapalı", systemImage: "shield.slash")
        case .on:      Label("Koruma aktif", systemImage: "shield.fill").foregroundStyle(.green)
        case .busy:    Label("…", systemImage: "hourglass")
        case .error(let msg): Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
        }
    }

    private var buttonTitle: String {
        switch proxy.state {
        case .on: return "Korumayı Kapat"
        case .busy: return "…"
        default: return "Korumayı Aç"
        }
    }
}

#Preview {
    ContentView().environmentObject(ProxyManager())
}
