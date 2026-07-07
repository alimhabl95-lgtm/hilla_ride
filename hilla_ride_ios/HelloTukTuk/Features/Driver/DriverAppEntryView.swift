import SwiftUI

struct DriverAppEntryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let driver = appState.currentDriver {
                if driver.isBlocked {
                    DriverBlockedView()
                } else {
                    switch driver.approvalStatus {
                    case .pending:
                        DriverPendingView()
                    case .rejected:
                        DriverRejectedView()
                    case .approved:
                        DriverHomeView(driver: driver)
                    }
                }
            } else if appState.currentUser?.role == .driver {
                DriverSignupView()
            } else {
                ProgressView(L10n.string(.loading, language: appState.language))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BrandColors.surface.ignoresSafeArea())
            }
        }
        .task(id: appState.currentUser?.uid) {
            await appState.refreshDriverProfileIfNeeded()
        }
    }
}

private struct DriverStatusView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(BrandColors.navy)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }
}

struct DriverBlockedView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        DriverStatusView(
            icon: "nosign",
            iconColor: .red,
            title: L10n.string(.driverBlockedTitle, language: appState.language),
            message: L10n.string(.driverBlockedMessage, language: appState.language)
        )
    }
}

struct DriverPendingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        DriverStatusView(
            icon: "hourglass",
            iconColor: BrandColors.tealDark,
            title: L10n.string(.driverPendingTitle, language: appState.language),
            message: L10n.string(.driverPendingMessage, language: appState.language)
        )
    }
}

struct DriverRejectedView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        DriverStatusView(
            icon: "xmark.circle",
            iconColor: .red,
            title: L10n.string(.driverRejectedTitle, language: appState.language),
            message: L10n.string(.driverRejectedMessage, language: appState.language)
        )
    }
}
