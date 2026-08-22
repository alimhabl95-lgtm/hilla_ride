import SwiftUI

struct CustomerAppEntryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var activeRide: Ride?
    @State private var sessionRideId: String?
    @State private var rideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let user = appState.currentUser {
                if !user.isProfileComplete {
                    CustomerProfileOnboardingView()
                } else if let sessionRideId {
                    CustomerActiveRideShell(
                        rideId: sessionRideId,
                        onSessionEnded: { self.sessionRideId = nil }
                    )
                } else {
                    CustomerHomeShellView(user: user)
                }
            }
        }
        .onAppear { startWatchingActiveRide() }
        .onDisappear {
            rideTask?.cancel()
            rideTask = nil
        }
           .onChange(of: appState.currentUser?.uid) { _ in
            startWatchingActiveRide()
        }
           .onChange(of: activeRide?.id) { newId in
            if let newId {
                sessionRideId = newId
            } else {
                // Ride ended/cancelled — return to home so the icon can reopen later.
                sessionRideId = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCurrentRide)) { _ in
            if let activeRide {
                sessionRideId = activeRide.id
            }
        }
    }

    private func startWatchingActiveRide() {
        rideTask?.cancel()
        guard let customerId = appState.currentUser?.uid else {
            activeRide = nil
            return
        }

        rideTask = Task {
            let repository = RideRepository()
            for await ride in repository.watchActiveRide(customerId: customerId) {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    activeRide = ride
                    if let ride {
                        sessionRideId = ride.id
                    }
                }
            }
        }
    }
}
