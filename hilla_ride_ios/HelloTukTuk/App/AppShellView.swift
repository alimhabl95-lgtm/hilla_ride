import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.currentUser != nil {
                switch appState.currentUser?.role {
                case .driver:
                    DriverAppEntryView()
                default:
                    CustomerAppEntryView()
                }
            }
        }
        .task(id: appState.currentUser?.uid) {
            await appState.refreshDriverProfileIfNeeded()
        }
    }
}

struct DriverPendingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            statusCard(
                icon: "clock.fill",
                title: L10n.string(.driverPendingTitle, language: appState.language),
                message: L10n.string(.driverPendingMessage, language: appState.language),
                color: BrandColors.gold
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle")
                    }
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
        }
    }
}

struct DriverRejectedView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        statusCard(
            icon: "xmark.circle.fill",
            title: L10n.string(.driverRejectedTitle, language: appState.language),
            message: L10n.string(.driverRejectedMessage, language: appState.language),
            color: .red
        )
    }
}

struct DriverBlockedView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        statusCard(
            icon: "hand.raised.fill",
            title: L10n.string(.driverBlockedTitle, language: appState.language),
            message: L10n.string(.driverBlockedMessage, language: appState.language),
            color: .red
        )
    }
}

private func statusCard(icon: String, title: String, message: String, color: Color) -> some View {
    VStack(spacing: 16) {
        Image(systemName: icon)
            .font(.system(size: 56))
            .foregroundStyle(color)
        Text(title)
            .font(.title2.bold())
            .multilineTextAlignment(.center)
        Text(message)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BrandColors.surface.ignoresSafeArea())
}
