import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var proxy: ProxyManager
    @StateObject private var counter = CounterStore()
    @Environment(\.colorScheme) private var scheme

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
                    Task { await proxy.toggle() }
                }

                StatusView(isOn: proxy.isOn, palette: palette)
                    .padding(.top, 24)

                Spacer(minLength: 12)

                CounterBlock(count: counter.count, isOn: proxy.isOn, palette: palette)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .task { counter.start() }
        .onDisappear { counter.stop() }
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
