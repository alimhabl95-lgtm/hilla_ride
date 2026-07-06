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

struct DriverBlockedView: View {
    var body: some View {
        Text("Your driver account has been blocked.")
            .padding()
    }
}

struct DriverPendingView: View {
    var body: some View {
        Text("Your driver application is pending approval.")
            .padding()
    }
}

struct DriverRejectedView: View {
    var body: some View {
        Text("Your driver application was rejected.")
            .padding()
    }
}
