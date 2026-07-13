import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var dns: DNSManager
    @Environment(\.colorScheme) private var scheme
    @AppStorage("didExplainPermission") private var didExplain = false
    @State private var showExplainer = false
    @State private var enableAfterExplainer = false

    private var palette: Palette { .resolve(scheme) }
    private var isPending: Bool { dns.state == .needsActivation }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView(palette: palette)

                Spacer(minLength: 12)

                HeroView(isOn: dns.isOn,
                         isBusy: dns.state == .busy,
                         isPending: isPending,
                         palette: palette) {
                    heroTapped()
                }

                StatusView(isOn: dns.isOn, isPending: isPending, palette: palette)
                    .padding(.top, 24)

                if isPending {
                    ActivationBanner(palette: palette) { openSettings() }
                        .padding(.top, 20)
                    Button("Remove configuration") {
                        Task { await dns.disable() }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondary)
                    .padding(.top, 10)
                }

                Spacer(minLength: 12)

                ProtectionFooter(isOn: dns.isOn, palette: palette)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
            // Keep the phone-designed column centered and readable on iPad.
            .frame(maxWidth: 480, maxHeight: 820)
        }
        // Any failure surfaces here — a tap always does something visible.
        .alert("Something went wrong", isPresented: Binding(
            get: { dns.errorMessage != nil },
            set: { if !$0 { dns.clearError() } }
        )) {
            Button("Try Again") { Task { await dns.enable() } }
            Button("OK", role: .cancel) { }
        } message: {
            Text(dns.errorMessage ?? "")
        }
        .sheet(isPresented: $showExplainer, onDismiss: {
            if enableAfterExplainer {
                enableAfterExplainer = false
                Task { await dns.enable() }
            }
        }) {
            PermissionExplainer(palette: palette) {
                didExplain = true
                enableAfterExplainer = true
                showExplainer = false
            }
        }
    }

    private func heroTapped() {
        switch dns.state {
        case .on:
            Task { await dns.disable() }
        case .needsActivation:
            openSettings()               // tap the control to finish enabling
        case .busy:
            break
        default:
            if !didExplain {
                showExplainer = true      // first time: explain the two-step flow
            } else {
                Task { await dns.enable() }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// One-time sheet shown before the very first enable, so the user understands
/// that turning Elek on installs an encrypted-DNS configuration and then needs a
/// quick switch-on in Settings.
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

            Text("Elek routes your device’s DNS through our private, encrypted resolver, which blocks ads and trackers across every app. It only sees which domains are looked up — never your traffic, pages, or messages — and keeps no logs.\n\nAfter you continue, iOS will ask you to switch Elek on in Settings.")
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
        .environmentObject(DNSManager())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView()
        .environmentObject(DNSManager())
        .preferredColorScheme(.dark)
}
