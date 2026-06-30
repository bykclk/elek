import SwiftUI

@main
struct ElekApp: App {
    @StateObject private var proxy = ProxyManager()
    @StateObject private var updater = BlocklistUpdater()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(proxy)
                .task {
                    // Seed (bundled) blocklist first so there is always something
                    // to mmap, then refresh to the full list over the network.
                    BlocklistInstaller.installIfNeeded()
                    await proxy.load()
                    updater.updateIfStale()
                }
        }
    }
}
