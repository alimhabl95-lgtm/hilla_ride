import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let user = appState.currentUser {
                switch user.role {
                case .driver:
                    DriverShellView()
                default:
                    CustomerHomeView()
                }
            }
        }
        .task(id: appState.currentUser?.uid) {
            await appState.refreshDriverProfileIfNeeded()
        }
    }
}

struct CustomerHomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "map.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandColors.teal)

                Text(L10n.string(.customerHomeTitle, language: appState.language))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if let user = appState.currentUser {
                    Text(user.name)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Text(L10n.string(.mapsComingSoon, language: appState.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandColors.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LanguageToggle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
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

struct DriverShellView: View {
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
            } else {
                ProgressView(L10n.string(.loading, language: appState.language))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BrandColors.surface.ignoresSafeArea())
            }
        }
    }
}

struct DriverHomeView: View {
    @EnvironmentObject private var appState: AppState
    let driver: DriverProfile
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandColors.gold)

                Text(L10n.string(.driverHomeTitle, language: appState.language))
                    .font(.title2.bold())

                Text(driver.name)
                    .font(.title3)

                Text("\(driver.vehiclePlate) · \(driver.vehicleColor)")
                    .foregroundStyle(.secondary)

                Text(L10n.string(.driverTripsComingSoon, language: appState.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BrandColors.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LanguageToggle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
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
                    Button {
                        showProfile = true
                    } label: {
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
