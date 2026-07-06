import CoreLocation
import FirebaseFirestore
import SwiftUI

struct CustomerActiveRideShell: View {
    @EnvironmentObject private var appState: AppState
    let rideId: String
    var onSessionEnded: (() -> Void)?

    @State private var ride: Ride?
    @State private var rideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let ride {
                switch ride.status {
                case .searching:
                    FindingDriverView(ride: ride, onSessionEnded: onSessionEnded)
                case .matched:
                    DriverAssignedView(ride: ride, onSessionEnded: onSessionEnded)
                case .accepted, .inProgress, .awaitingCashPayment:
                    ActiveRideMapView(ride: ride)
                case .completed:
                    TripCompletedView(rideId: ride.id, onFinished: onSessionEnded)
                case .cancelled:
                    sessionEndedView
                }
            } else {
                ProgressView(L10n.string(.loading, language: appState.language))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(BrandColors.surface.ignoresSafeArea())
            }
        }
        .onAppear { startWatchingRide() }
        .onDisappear {
            rideTask?.cancel()
            rideTask = nil
        }
    }

    private var sessionEndedView: some View {
        VStack {
            Text(L10n.string(.rideCancelled, language: appState.language))
            Button(L10n.string(.done, language: appState.language)) {
                onSessionEnded?()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }

    private func startWatchingRide() {
        rideTask?.cancel()
        rideTask = Task {
            let repository = RideRepository()
            for await updatedRide in repository.watchRide(rideId: rideId) {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    ride = updatedRide
                }
            }
        }
    }
}

struct FindingDriverView: View {
    @EnvironmentObject private var appState: AppState
    let ride: Ride
    var onSessionEnded: (() -> Void)?

    @State private var isRetrying = false
    @State private var waitingForDrivers = false
    @State private var retryTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text(L10n.string(.findingDriver, language: appState.language))
                .font(.title2.bold())
            Text(
                waitingForDrivers
                    ? L10n.string(.noDriversInDistrict, language: appState.language)
                    : L10n.string(.findingDriverHint, language: appState.language)
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            if waitingForDrivers {
                Text(L10n.string(.retryDriverSearch, language: appState.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(L10n.string(.retryDriverSearch, language: appState.language)) {
                Task { await retryAssignment() }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(isRetrying)

            Button(L10n.string(.cancelRide, language: appState.language)) {
                Task { await cancelRide() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .tint(.red)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
        .onAppear {
            Task { await retryAssignment() }
        }
        .onDisappear {
            retryTask?.cancel()
        }
    }

    private func retryAssignment() async {
        guard !isRetrying else { return }
        isRetrying = true
        defer { isRetrying = false }

        do {
            try await RideRepository().assignNearestDriver(rideId: ride.id)
            waitingForDrivers = false
            retryTask?.cancel()
        } catch RideServiceError.noDrivers {
            waitingForDrivers = true
            scheduleAutoRetry()
        } catch {
            waitingForDrivers = false
        }
    }

    private func scheduleAutoRetry() {
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            await retryAssignment()
        }
    }

    private func cancelRide() async {
        guard let customerId = appState.currentUser?.uid else { return }
        retryTask?.cancel()
        try? await RideRepository().cancelRide(rideId: ride.id, cancelledBy: customerId)
        onSessionEnded?()
    }
}

struct DriverAssignedView: View {
    @EnvironmentObject private var appState: AppState
    let ride: Ride
    var onSessionEnded: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.fill")
                .font(.system(size: 56))
                .foregroundStyle(BrandColors.gold)
            Text(L10n.string(.waitingForDriver, language: appState.language))
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(L10n.string(.waitingForDriverHint, language: appState.language))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(L10n.string(.cancelRide, language: appState.language)) {
                Task {
                    guard let customerId = appState.currentUser?.uid else { return }
                    try? await RideRepository().cancelRide(rideId: ride.id, cancelledBy: customerId)
                    onSessionEnded?()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .tint(.red)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }
}

struct ActiveRideMapView: View {
    @EnvironmentObject private var appState: AppState
    let ride: Ride

    @State private var driverCoordinate: CLLocationCoordinate2D?
    @State private var driverTask: Task<Void, Never>?
    @State private var showChat = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if MapsConfig.isConfigured {
                    GoogleMapView(
                        cameraTarget: ride.pickupCoordinate,
                        zoom: 14,
                        pickup: MapPlace(label: ride.pickupLabel, coordinate: ride.pickupCoordinate),
                        destination: MapPlace(label: ride.destinationLabel, coordinate: ride.destinationCoordinate),
                        driverCoordinate: driverCoordinate
                    )
                    .ignoresSafeArea()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(formatIqd(ride.fareAmountIqd))
                        .font(.title3.bold())
                        .foregroundStyle(BrandColors.tealDark)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(12)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showChat = true
                    } label: {
                        Image(systemName: "message.fill")
                    }
                }
            }
            .navigationDestination(isPresented: $showChat) {
                RideChatView(rideId: ride.id)
            }
        }
        .onAppear { startWatchingDriver() }
        .onDisappear {
            driverTask?.cancel()
            driverTask = nil
        }
          .onChange(of: ride.driverId) { _ in
            startWatchingDriver()
        }
    }

    private var statusTitle: String {
        switch ride.status {
        case .accepted:
            return L10n.string(.driverOnTheWay, language: appState.language)
        case .inProgress:
            return L10n.string(.rideInProgress, language: appState.language)
        case .awaitingCashPayment:
            return L10n.string(.awaitingCashPayment, language: appState.language)
        default:
            return L10n.string(.rideInProgress, language: appState.language)
        }
    }

    private func formatIqd(_ amount: Int) -> String {
        appState.language == .arabic ? "\(amount) د.ع" : "\(amount) IQD"
    }

    private func startWatchingDriver() {
        driverTask?.cancel()
        guard let driverId = ride.driverId else {
            driverCoordinate = nil
            return
        }

        driverTask = Task {
            let firestore = Firestore.firestore()
            let stream = AsyncStream<CLLocationCoordinate2D?> { continuation in
                let listener = firestore.collection("drivers").document(driverId)
                    .addSnapshotListener { snapshot, _ in
                        guard let data = snapshot?.data(),
                              let lat = (data["latitude"] as? NSNumber)?.doubleValue,
                              let lng = (data["longitude"] as? NSNumber)?.doubleValue else {
                            continuation.yield(nil)
                            return
                        }
                        continuation.yield(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                    }
                continuation.onTermination = { _ in
                    listener.remove()
                }
            }

            for await coordinate in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    driverCoordinate = coordinate
                }
            }
        }
    }
}
"Fix iOS 17 onChange"
