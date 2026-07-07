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
    @State private var showCompletedHistory = false
    @State private var showCancelledHistory = false
    @State private var showSupport = false
    @State private var showAnnouncements = false
    @State private var showChat = false
    @State private var monthlyStats: DriverMonthlyStats?
    @State private var statsTask: Task<Void, Never>?
    @State private var activeCustomer: AppUser?
    @State private var customerTask: Task<Void, Never>?
    @State private var cancelledCount = 0
    @State private var cancelledTask: Task<Void, Never>?

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
            .navigationTitle(L10n.string(.driverHomeTitle, language: appState.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LanguageToggle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .navigationDestination(isPresented: $showCompletedHistory) {
                RideHistoryView(
                    customerId: nil,
                    driverId: driver.uid,
                    statusFilter: .completed,
                    title: L10n.string(.completedRidesCount, language: appState.language)
                )
            }
            .navigationDestination(isPresented: $showCancelledHistory) {
                RideHistoryView(
                    customerId: nil,
                    driverId: driver.uid,
                    statusFilter: .cancelled,
                    title: L10n.string(.cancelledRidesCount, language: appState.language)
                )
            }
            .navigationDestination(isPresented: $showSupport) {
                SupportView()
            }
            .navigationDestination(isPresented: $showAnnouncements) {
                AnnouncementsView()
            }
            .navigationDestination(isPresented: $showChat) {
                if let ride = activeRide {
                    RideChatView(rideId: ride.id)
                }
            }
        }
        .onAppear { startWatching() }
        .onDisappear { stopWatching() }
        .onChange(of: activeRide?.customerId) { customerId in
            startWatchingCustomer(customerId)
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button {
                showProfile = true
            } label: {
                Label(L10n.string(.profileTitle, language: appState.language), systemImage: "person.circle")
            }
            Button {
                showAnnouncements = true
            } label: {
                Label(L10n.string(.announcementsTitle, language: appState.language), systemImage: "megaphone")
            }
            Button {
                showSupport = true
            } label: {
                Label(L10n.string(.supportTitle, language: appState.language), systemImage: "headphones")
            }
            Link(destination: LegalConfig.privacyPolicyURL(languageCode: appState.language.rawValue)) {
                Label(L10n.string(.privacyPolicy, language: appState.language), systemImage: "lock.doc")
            }
            Link(destination: LegalConfig.termsOfServiceURL(languageCode: appState.language.rawValue)) {
                Label(L10n.string(.termsOfService, language: appState.language), systemImage: "doc.text")
            }
            Divider()
            Button(role: .destructive) {
                Task { try? await appState.signOut() }
            } label: {
                Label(L10n.string(.logout, language: appState.language), systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
        }
    }

    private var idleDriverPanel: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandColors.gold)

                Text(currentDriver.name)
                    .font(.title2.bold())
                    .foregroundStyle(BrandColors.navy)

                availabilityCard

                tripsStatsRow

                if let monthlyStats {
                    monthlyPrizeCard(stats: monthlyStats)
                }

                earningsCard(driver: currentDriver)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }

    private var availabilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.driverAvailabilityTitle, language: appState.language))
                .font(.headline)
                .foregroundStyle(BrandColors.navy)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        currentDriver.isOnline
                            ? L10n.string(.goOnline, language: appState.language)
                            : L10n.string(.goOffline, language: appState.language)
                    )
                    .font(.title3.bold())
                    .foregroundStyle(currentDriver.isOnline ? BrandColors.tealDark : .secondary)

                    Text(availabilityHint)
                        .font(.footnote)
                        .foregroundStyle(currentDriver.hasAssignedWorkArea ? Color.secondary : Color.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { currentDriver.isOnline },
                        set: { value in Task { await setOnline(value) } }
                    )
                )
                .labelsHidden()
                .tint(BrandColors.teal)
                .disabled(isUpdatingOnline || !currentDriver.hasAssignedWorkArea)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var availabilityHint: String {
        if !currentDriver.hasAssignedWorkArea {
            return L10n.string(.driverWorkAreaRequired, language: appState.language)
        }
        return currentDriver.isOnline
            ? L10n.string(.driverWaitingForRequests, language: appState.language)
            : L10n.string(.driverGoOnlineHint, language: appState.language)
    }

    private var tripsStatsRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: L10n.string(.completedRidesCount, language: appState.language),
                value: currentDriver.completedRidesCount,
                icon: "checkmark.circle.fill",
                color: BrandColors.tealDark
            ) {
                showCompletedHistory = true
            }

            statCard(
                title: L10n.string(.cancelledRidesCount, language: appState.language),
                value: cancelledCount,
                icon: "xmark.circle.fill",
                color: .red
            ) {
                showCancelledHistory = true
            }
        }
    }

    private func statCard(
        title: String,
        value: Int,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text("\(value)")
                    .font(.title.bold())
                    .foregroundStyle(BrandColors.navy)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func monthlyPrizeCard(stats: DriverMonthlyStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.string(.driverMonthlyPrizeTitle, language: appState.language), systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(BrandColors.gold)
            Text(L10n.driverMonthlyRideCount(stats.rideCount, language: appState.language))
                .font(.title2.bold())
            Text(L10n.driverMonthlyRank(stats.rank, stats.totalDrivers, language: appState.language))
                .font(.subheadline)
            Text(L10n.driverMonthlyPrizeAmount(formatIqd(stats.prizeAmountIqd), language: appState.language))
                .font(.subheadline)
                .foregroundStyle(BrandColors.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BrandColors.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func earningsCard(driver: DriverProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string(.yourEarningsTitle, language: appState.language))
                .font(.headline)
            Text("\(L10n.string(.completedRidesCount, language: appState.language)): \(driver.completedRidesCount)")
            Text("\(L10n.string(.driverNetEarnings, language: appState.language)): \(formatIqd(driver.totalDriverEarningsIqd))")
            Text("\(L10n.string(.owedToPlatformLabel, language: appState.language)): \(formatIqd(driver.outstandingPlatformCommissionIqd))")
            if driver.pendingBonusIqd > 0 {
                Text("\(L10n.string(.pendingBonusLabel, language: appState.language)): \(formatIqd(driver.pendingBonusIqd))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func driverRidePanel(ride: Ride) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if MapsConfig.isConfigured {
                    GoogleMapView(
                        cameraTarget: ride.pickupCoordinate,
                        zoom: 14,
                        pickup: MapPlace(label: ride.pickupLabel, coordinate: ride.pickupCoordinate),
                        destination: MapPlace(label: ride.destinationLabel, coordinate: ride.destinationCoordinate)
                    )
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        ProfileAvatarView(
                            name: activeCustomer?.name ?? "",
                            photoURL: activeCustomer?.profilePhotoUrl,
                            size: 56
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rideStatusTitle(ride.status))
                                .font(.headline)
                            if let name = activeCustomer?.name, !name.isEmpty {
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    Text("\(ride.pickupLabel) → \(ride.destinationLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatIqd(ride.fareAmountIqd))
                        .font(.title2.bold())
                        .foregroundStyle(BrandColors.tealDark)

                    Button {
                        showChat = true
                    } label: {
                        Label(L10n.string(.messageCustomer, language: appState.language), systemImage: "message.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 24)

                rideActions(for: ride)
                    .padding(.horizontal, 24)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        startWatchingCustomer(activeRide?.customerId)
        statsTask = Task {
            for await stats in MonthlyPrizeService().watchDriverStats(driverId: driverId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { monthlyStats = stats }
            }
        }
        cancelledTask = Task {
            for await rides in RideRepository().watchRideHistoryForDriver(driverId: driverId, statusFilter: .cancelled) {
                guard !Task.isCancelled else { break }
                await MainActor.run { cancelledCount = rides.count }
            }
        }
    }

    private func stopWatching() {
        driverTask?.cancel()
        rideTask?.cancel()
        statsTask?.cancel()
        customerTask?.cancel()
        cancelledTask?.cancel()
    }

    private func startWatchingCustomer(_ customerId: String?) {
        customerTask?.cancel()
        activeCustomer = nil
        guard let customerId, !customerId.isEmpty else { return }
        customerTask = Task {
            for await user in UserRepository().watchUser(uid: customerId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { activeCustomer = user }
            }
        }
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
