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
