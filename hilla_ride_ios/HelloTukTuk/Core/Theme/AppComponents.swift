import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(BrandColors.teal.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(BrandColors.teal, lineWidth: 1.5)
            }
            .foregroundStyle(BrandColors.tealDark)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            }
    }
}

struct LanguageToggle: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button(language == .arabic ? L10n.string(.arabic, language: appState.language) : L10n.string(.english, language: appState.language)) {
                    appState.language = language
                }
            }
        } label: {
            Label(L10n.string(.language, language: appState.language), systemImage: "globe")
        }
    }
}

struct LoadingOverlay: View {
    let isLoading: Bool

    var body: some View {
        if isLoading {
            ZStack {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView(L10n.string(.loading))
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
