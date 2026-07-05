import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isBootstrapping {
                ProgressView(L10n.string(.loading, language: appState.language))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BrandColors.surface.ignoresSafeArea())
            } else if appState.currentUser != nil {
                PlaceholderHomeView()
            } else {
                ModeChooserView()
            }
        }
        .environment(\.layoutDirection, appState.language.layoutDirection)
        .task {
            await appState.finishBootstrap()
        }
    }
}
