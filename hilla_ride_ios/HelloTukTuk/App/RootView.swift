import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                WelcomeSplashView { showSplash = false }
            } else {
                content
            }
        }
        .environment(\.layoutDirection, appState.language.layoutDirection)
        .task {
            await appState.finishBootstrap()
        }
    }

    @ViewBuilder
    private var content: some View {
        if appState.isBootstrapping {
            ProgressView(L10n.string(.loading, language: appState.language))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BrandColors.surface.ignoresSafeArea())
        } else if appState.currentUser != nil {
            AppShellView()
        } else if appState.needsProfileRecovery {
            MissingProfileRecoveryView()
        } else {
            ModeChooserView()
        }
    }
}
