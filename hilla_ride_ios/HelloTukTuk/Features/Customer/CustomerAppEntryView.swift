import SwiftUI

struct CustomerAppEntryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var activeRide: Ride?
    @State private var rideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let user = appState.currentUser {
                if let activeRide {
                    CustomerActiveRideShell(rideId: activeRide.id)
                } else {
                    CustomerHomeMapView(user: user)
                }
            }
        }
        .onAppear { startWatchingActiveRide() }
        .onDisappear {
            rideTask?.cancel()
            rideTask = nil
        }
        .onChange(of: appState.currentUser?.uid) { _, _ in
            startWatchingActiveRide()
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
                }
            }
        }
    }
}
