import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var proxy: ProxyManager
    @StateObject private var counter = CounterStore()
    @Environment(\.colorScheme) private var scheme
    @AppStorage("didExplainPermission") private var didExplain = false
    @State private var showExplainer = false

    private var palette: Palette { .resolve(scheme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView(palette: palette)

                Spacer(minLength: 12)

                HeroView(isOn: proxy.isOn,
                         isBusy: proxy.state == .busy,
                         palette: palette) {
                    heroTapped()
                }

                StatusView(isOn: proxy.isOn, palette: palette)
                    .padding(.top, 24)

                Spacer(minLength: 12)

                CounterBlock(count: counter.count, isOn: proxy.isOn, palette: palette)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
            // Keep the phone-designed column centered and readable on iPad,
            // instead of stretching across a large regular-size-class screen.
            .frame(maxWidth: 480, maxHeight: 820)
        }
        .task { counter.start() }
        .onDisappear { counter.stop() }
        // Any failure to turn protection on is shown here — a tap always does
        // something visible, never a silent no-op.
        .alert("Couldn’t turn on protection", isPresented: Binding(
            get: { proxy.errorMessage != nil },
            set: { if !$0 { proxy.clearError() } }
        )) {
            Button("Try Again") { Task { await proxy.enable() } }
            Button("OK", role: .cancel) { }
        } message: {
            Text((proxy.errorMessage ?? "")
                 + "\n\nIf you didn’t see a permission prompt, you can also enable Elek in Settings › General › VPN & Device Management.")
        }
        .sheet(isPresented: $showExplainer) {
            PermissionExplainer(palette: palette) {
                didExplain = true
                showExplainer = false
                Task { await proxy.enable() }
            }
        }
    }

    private func heroTapped() {
        if proxy.isOn {
            Task { await proxy.disable() }
        } else if !didExplain {
            showExplainer = true          // first time: explain the system prompt
        } else {
            Task { await proxy.enable() }
        }
    }
}

/// One-time sheet shown before the very first enable, so the user (and the App
/// Review team) understands the upcoming "Add Proxy Configurations" system prompt.
struct PermissionExplainer: View {
    let palette: Palette
    var onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x4FB6A0), Color(hex: 0x2E7E6C)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 84, height: 84)
                .overlay(ElekMark(color: .white, lineWidth: 6).frame(width: 46, height: 46))

            Text("Turn on protection")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.text)

            Text("Elek installs a private, on-device DNS filter that blocks ads and trackers across every app. iOS will now ask permission to add a VPN configuration — it’s a local filter only: there is no VPN server, and your browsing data never leaves your device.")
                .font(.system(size: 15))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer(minLength: 8)

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }

            Button("Not now") { dismiss() }
                .font(.system(size: 15))
                .foregroundStyle(palette.secondary)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: 460)
        .padding(.horizontal, 24)
        .presentationDetents([.medium, .large])
    }
}

#Preview("Light") {
    ContentView()
        .environmentObject(ProxyManager())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView()
        .environmentObject(ProxyManager())
        .preferredColorScheme(.dark)
}
