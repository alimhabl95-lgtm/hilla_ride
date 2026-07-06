import SwiftUI

struct DriverHomeView: View {
    @EnvironmentObject private var appState: AppState
    let driver: DriverProfile

    @State private var liveDriver: DriverProfile?
    @State private var activeRide: Ride?
    @State private var driverTask: Task<Void, Never>?
    @State private var rideTask: Task<Void, Never>?
    @State private var isUpdatingOnline = false
    @State private var errorMessage: String?
    @State private var showProfile = false
    @State private var showHistory = false
    @State private var showSupport = false
    @State private var showChat = false

    private var currentDriver: DriverProfile {
        liveDriver ?? driver
    }

    var body: some View {
        NavigationStack {
            Group {
                if let ride = activeRide {
                    driverRidePanel(ride: ride)
                } else {
                    idleDriverPanel
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LanguageToggle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if activeRide != nil {
                            Button {
                                showChat = true
                            } label: {
                                Image(systemName: "message.fill")
                            }
                        }
                        Button {
                            showHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        Button {
                            showSupport = true
                        } label: {
                            Image(systemName: "lifepreserver")
                        }
                        onlineToggle
                        Button {
                            showProfile = true
                        } label: {
                            Image(systemName: "person.circle")
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .navigationDestination(isPresented: $showHistory) {
                RideHistoryView(customerId: nil, driverId: driver.uid)
            }
            .navigationDestination(isPresented: $showSupport) {
                SupportView()
            }
            .navigationDestination(isPresented: $showChat) {
                if let ride = activeRide {
                    RideChatView(rideId: ride.id)
                }
            }
        }
        .onAppear { startWatching() }
        .onDisappear { stopWatching() }
    }

    private var onlineToggle: some View {
        Toggle(
            isOn: Binding(
                get: { currentDriver.isOnline },
                set: { value in Task { await setOnline(value) } }
            )
        ) {
            Text(
                currentDriver.isOnline
                    ? L10n.string(.goOnline, language: appState.language)
                    : L10n.string(.goOffline, language: appState.language)
            )
            .font(.caption)
        }
        .labelsHidden()
        .disabled(isUpdatingOnline || !currentDriver.hasAssignedWorkArea)
    }

    private var idleDriverPanel: some View {
        VStack(spacing: 16) {
            Image(systemName: "car.side.fill")
                .font(.system(size: 56))
                .foregroundStyle(BrandColors.gold)

            Text(L10n.string(.driverHomeTitle, language: appState.language))
                .font(.title2.bold())

            Text(currentDriver.name)
                .font(.title3)

            if !currentDriver.hasAssignedWorkArea {
                Text(L10n.string(.driverWorkAreaRequired, language: appState.language))
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if !currentDriver.isOnline {
                Text(L10n.string(.driverGoOnlineHint, language: appState.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text(L10n.string(.driverWaitingForRequests, language: appState.language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }

    @ViewBuilder
    private func driverRidePanel(ride: Ride) -> some View {
        VStack(spacing: 16) {
            if MapsConfig.isConfigured {
                GoogleMapView(
                    cameraTarget: ride.pickupCoordinate,
                    zoom: 14,
                    pickup: MapPlace(label: ride.pickupLabel, coordinate: ride.pickupCoordinate),
                    destination: MapPlace(label: ride.destinationLabel, coordinate: ride.destinationCoordinate)
                )
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(rideStatusTitle(ride.status))
                    .font(.headline)
                Text("\(ride.pickupLabel) → \(ride.destinationLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatIqd(ride.fareAmountIqd))
                    .font(.title2.bold())
                    .foregroundStyle(BrandColors.tealDark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            rideActions(for: ride)
                .padding(.horizontal, 24)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .background(BrandColors.surface.ignoresSafeArea())
    }

    @ViewBuilder
    private func rideActions(for ride: Ride) -> some View {
        switch ride.status {
        case .matched:
            HStack(spacing: 12) {
                Button(L10n.string(.acceptRide, language: appState.language)) {
                    Task { await accept(ride) }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(L10n.string(.rejectRide, language: appState.language)) {
                    Task { await reject(ride) }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        case .accepted:
            Button(L10n.string(.startRide, language: appState.language)) {
                Task { await start(ride) }
            }
            .buttonStyle(PrimaryButtonStyle())
        case .inProgress:
            Button(L10n.string(.endRide, language: appState.language)) {
                Task { await endRide(ride) }
            }
            .buttonStyle(PrimaryButtonStyle())
        case .awaitingCashPayment:
            Button(L10n.string(.confirmCashCollected, language: appState.language)) {
                Task { await confirmCash(ride) }
            }
            .buttonStyle(PrimaryButtonStyle())
        default:
            EmptyView()
        }
    }

    private func rideStatusTitle(_ status: RideStatus) -> String {
        switch status {
        case .matched: return L10n.string(.newRideOffer, language: appState.language)
        case .accepted: return L10n.string(.rideAccepted, language: appState.language)
        case .inProgress: return L10n.string(.rideInProgress, language: appState.language)
        case .awaitingCashPayment: return L10n.string(.awaitingCashPayment, language: appState.language)
        default: return L10n.string(.driverHomeTitle, language: appState.language)
        }
    }

    private func formatIqd(_ amount: Int) -> String {
        appState.language == .arabic ? "\(amount) د.ع" : "\(amount) IQD"
    }

    private func startWatching() {
        let driverId = driver.uid
        driverTask = Task {
            for await profile in DriverRepository().watchDriver(uid: driverId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { liveDriver = profile }
            }
        }
        rideTask = Task {
            for await ride in RideRepository().watchAssignedRide(for: driverId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { activeRide = ride }
            }
        }
    }

    private func stopWatching() {
        driverTask?.cancel()
        rideTask?.cancel()
    }

    private func setOnline(_ value: Bool) async {
        errorMessage = nil
        isUpdatingOnline = true
        defer { isUpdatingOnline = false }
        do {
            try await DriverRepository().setOnlineStatus(driverId: driver.uid, isOnline: value)
            await appState.refreshDriverProfileIfNeeded()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func accept(_ ride: Ride) async {
        errorMessage = nil
        do {
            try await RideRepository().acceptRide(rideId: ride.id, driverId: driver.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reject(_ ride: Ride) async {
        errorMessage = nil
        do {
            try await RideRepository().rejectRide(rideId: ride.id, driverId: driver.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func start(_ ride: Ride) async {
        errorMessage = nil
        do {
            try await RideRepository().startRide(rideId: ride.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func endRide(_ ride: Ride) async {
        errorMessage = nil
        do {
            try await RideRepository().endRideAwaitingCash(rideId: ride.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmCash(_ ride: Ride) async {
        errorMessage = nil
        do {
            try await RideRepository().confirmCashCollected(rideId: ride.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
