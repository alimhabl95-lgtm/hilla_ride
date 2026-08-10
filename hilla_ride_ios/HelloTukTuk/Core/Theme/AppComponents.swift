import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(BrandColors.teal.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        let color = destructive ? BrandColors.danger : BrandColors.tealDark
        return configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(color)
            .overlay {
                RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous)
                    .stroke(color, lineWidth: 1.5)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous)
                    .stroke(BrandColors.border, lineWidth: 1)
            }
    }
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.lg)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                    .stroke(BrandColors.border, lineWidth: 1)
            }
            .shadow(color: BrandColors.navy.opacity(0.06), radius: 12, y: 6)
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}

struct AppWalletCard: View {
    let title: String
    let balance: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(balance)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.75))
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(BrandColors.tealDark)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.xl)
        .background(
            LinearGradient(
                colors: [BrandColors.teal, BrandColors.tealDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadii.xl, style: .continuous))
        .shadow(color: BrandColors.navy.opacity(0.12), radius: 16, y: 8)
    }
}

struct AppStatCard: View {
    let label: String
    let value: String
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.tealDark)
                    .padding(8)
                    .background(BrandColors.teal.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous))
            }
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandColors.navy)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(BrandColors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

struct AppBanner: View {
    enum Tone { case info, warning, danger, success }

    let message: String
    var systemImage = "info.circle"
    var tone: Tone = .info

    private var colors: (Color, Color) {
        switch tone {
        case .info: return (BrandColors.teal.opacity(0.12), BrandColors.tealDark)
        case .warning: return (BrandColors.warning.opacity(0.15), Color(red: 0.706, green: 0.325, blue: 0.035))
        case .danger: return (BrandColors.danger.opacity(0.12), BrandColors.danger)
        case .success: return (BrandColors.success.opacity(0.12), BrandColors.success)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
            Text(message)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(colors.1)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(colors.0)
        .clipShape(RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
    }
}

struct AppEmptyState: View {
    let title: String
    var message: String?
    var systemImage = "tray"

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(BrandColors.tealDark)
                .padding(18)
                .background(BrandColors.teal.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(BrandColors.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.xxl)
    }
}

struct AppSheetHandle: View {
    var body: some View {
        Capsule()
            .fill(BrandColors.border)
            .frame(width: 40, height: 4)
            .padding(.bottom, 8)
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
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
            }
            .transition(.opacity)
        }
    }
}
