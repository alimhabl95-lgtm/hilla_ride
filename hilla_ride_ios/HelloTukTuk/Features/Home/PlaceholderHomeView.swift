import SwiftUI

struct PlaceholderHomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandColors.teal)

                Text(L10n.string(.welcomeSignedIn, language: appState.language))
                    .font(.title2.bold())

                if let user = appState.currentUser {
                    Text(user.name)
                        .font(.title3)
                    Text(user.role.rawValue.capitalized)
                        .foregroundStyle(.secondary)
                }

                Text("Phase 1: Maps and ride booking arrive next.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(L10n.string(.logout, language: appState.language)) {
                    Task {
                        try? await appState.signOut()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 12)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandColors.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageToggle()
                }
            }
        }
    }
}
