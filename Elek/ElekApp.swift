import SwiftUI

@main
struct ElekApp: App {
    @StateObject private var proxy = ProxyManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(proxy)
                .task {
                    BlocklistInstaller.installIfNeeded()
                    await proxy.load()
                }
        }
    }
}
