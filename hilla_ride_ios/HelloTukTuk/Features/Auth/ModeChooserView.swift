import SwiftUI

struct ModeChooserView: View {
    @EnvironmentObject private var appState: AppState
    @State private var navigateToAuth = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 16)

                Image(systemName: "car.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandColors.gold)
                    .frame(width: 120, height: 120)
                    .background(BrandColors.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 28))

                Text(L10n.string(.appTitle, language: appState.language))
                    .font(.largeTitle.bold())
                    .foregroundStyle(BrandColors.navy)

                Text(L10n.string(.modeChooserSubtitle, language: appState.language))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                Spacer()

                modeTile(
                    title: L10n.string(.takeRide, language: appState.language),
                    subtitle: L10n.string(.takeRideDesc, language: appState.language),
                    color: BrandColors.gold,
                    icon: "person.crop.circle"
                ) {
                    appState.selectMode(.customer)
                    navigateToAuth = true
                }

                modeTile(
                    title: L10n.string(.driveAndEarn, language: appState.language),
                    subtitle: L10n.string(.driveAndEarnDesc, language: appState.language),
                    color: BrandColors.tealDark,
                    icon: "car.side.fill"
                ) {
                    appState.selectMode(.driver)
                    navigateToAuth = true
                }

                Spacer(minLength: 32)
            }
            .padding(24)
            .background(BrandColors.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LanguageToggle()
                }
            }
            .navigationDestination(isPresented: $navigateToAuth) {
                AuthFlowView()
            }
        }
    }

    private func modeTile(
        title: String,
        subtitle: String,
        color: Color,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                    .frame(width: 64, height: 64)
                    .background(color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(BrandColors.navy)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.forward")
                    .foregroundStyle(color)
            }
            .padding(24)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
