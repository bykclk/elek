import SwiftUI

@main
struct ElekApp: App {
    @StateObject private var dns = DNSManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dns)
                .task { await dns.load() }
                // Re-read the system state whenever we return to the foreground,
                // so flipping Elek on/off in Settings is reflected immediately.
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Task { await dns.load() }
                    }
                }
        }
    }
}
