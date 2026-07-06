import SwiftUI

struct WelcomeSplashView: View {
    let onFinished: () -> Void

    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            BrandColors.tealDark.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "car.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(BrandColors.gold)
                Text(L10n.string(.appTitle))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.6)) {
                opacity = 1
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                onFinished()
            }
        }
    }
}

struct WelcomeSplashGate<Content: View>: View {
    @AppStorage("welcome_splash_seen") private var welcomeSplashSeen = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        if welcomeSplashSeen {
            content()
        } else {
            WelcomeSplashView {
                welcomeSplashSeen = true
            }
        }
    }
}
