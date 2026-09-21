import SwiftUI

struct CustomerAppEntryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var activeRide: Ride?
    @State private var sessionRideId: String?
    @State private var minimizedRideId: String?
    @State private var rideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let user = appState.currentUser {
                if !user.isProfileComplete {
                    CustomerProfileOnboardingView()
                } else if let sessionRideId {
                    CustomerActiveRideShell(
                        rideId: sessionRideId,
                        onSessionEnded: {
                            self.sessionRideId = nil
                            self.minimizedRideId = nil
                        },
                        onMinimize: {
                            self.minimizedRideId = sessionRideId
                            self.sessionRideId = nil
                        }
                    )
                } else {
                    CustomerHomeShellView(
                        user: user,
                        activeRideId: activeRide?.id,
                        onOpenCurrentRide: {
                            guard let id = activeRide?.id else { return }
                            sessionRideId = id
                            minimizedRideId = nil
                        }
                    )
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
            if newId == nil {
                sessionRideId = nil
                minimizedRideId = nil
                return
            }
            guard let newId else { return }
            if sessionRideId == newId { return }
            if minimizedRideId == newId { return }
            sessionRideId = newId
            minimizedRideId = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCurrentRide)) { _ in
            if let activeRide {
                sessionRideId = activeRide.id
                minimizedRideId = nil
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
                }
            }
        }
    }
}
