import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let user = appState.currentUser, user.isBlocked {
                BlockedUserView()
            } else {
                SessionGuardView {
                    RideAlertOverlay {
                        roleContent
                    }
                }
            }
        }
        .task(id: appState.currentUser?.uid) {
            await appState.refreshDriverProfileIfNeeded()
            if let user = appState.currentUser {
                RideAlertService.shared.startListeners(uid: user.uid, role: user.role)
            }
        }
        .onDisappear {
            RideAlertService.shared.stopListeners()
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