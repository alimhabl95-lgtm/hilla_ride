import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let user = appState.currentUser, user.isBlocked {
                BlockedUserView()
            } else {
                SessionGuardView {
                    roleContent
                }
            }
        }
        .task(id: appState.currentUser?.uid) {
            await appState.refreshDriverProfileIfNeeded()
        }
    }

    @ViewBuilder
    private var roleContent: some View {
        switch appState.currentUser?.role {
        case .driver:
            DriverAppEntryView()
        default:
            CustomerAppEntryView()
        }
    }
}

struct DriverPendingView: View {