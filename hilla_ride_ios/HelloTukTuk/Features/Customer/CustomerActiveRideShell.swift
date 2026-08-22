import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import UIKit

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
        .onAppear {
            startWatchingRide()
            if let uid = Auth.auth().currentUser?.uid {
                CustomerLocationPublisher.shared.start(for: uid)
            }
        }
        .onDisappear {
            rideTask?.cancel()
            rideTask = nil
            CustomerLocationPublisher.shared.stop()
        }
    }

    private var sessionEndedView: some View {
        VStack(spacing: AppSpacing.xl) {
            AppEmptyState(
                title: L10n.string(.rideCancelled, language: appState.language),
                systemImage: "xmark.circle"
            )
            Button(L10n.string(.done, language: appState.language)) {
                onSessionEnded?()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, AppSpacing.xxl)
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
    @State private var isCancelling = false
    @State private var waitingForDrivers = false
    @State private var actionError: String?
    @State private var assignmentTask: Task<Void, Never>?
    @State private var autoRetryTask: Task<Void, Never>?
    @State private var pulseScale: CGFloat = 1

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            SearchingPulseView(scale: pulseScale)

            VStack(spacing: AppSpacing.sm) {
                Text(L10n.string(.findingDriver, language: appState.language))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(BrandColors.navy)

                Text(
                    waitingForDrivers
                        ? L10n.string(.noDriversInDistrict, language: appState.language)
                        : L10n.string(.findingDriverHint, language: appState.language)
                )
                .font(.subheadline)
                .foregroundStyle(BrandColors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)
            }

            if waitingForDrivers {
                AppBanner(
                    message: L10n.string(.retryDriverSearch, language: appState.language),
                    systemImage: "arrow.clockwise",
                    tone: .warning
                )
                .padding(.horizontal, AppSpacing.xl)
            }

            if let actionError {
                AppBanner(
                    message: actionError,
                    systemImage: "exclamationmark.triangle.fill",
                    tone: .danger
                )
                .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            VStack(spacing: AppSpacing.md) {
                Button {
                    startAssignment(manual: true)
                } label: {
                    HStack {
                        if isRetrying {
                            ProgressView()
                                .tint(BrandColors.tealDark)
                        }
                        Text(L10n.string(.retryDriverSearch, language: appState.language))
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(isRetrying || isCancelling)
                .opacity((isRetrying || isCancelling) ? 0.55 : 1)

                Button {
                    Task { await cancelRide() }
                } label: {
                    HStack {
                        if isCancelling {
                            ProgressView()
                                .tint(BrandColors.danger)
                        }
                        Text(L10n.string(.cancelRide, language: appState.language))
                    }
                }
                .buttonStyle(SecondaryButtonStyle(destructive: true))
                .disabled(isCancelling)
                .opacity(isCancelling ? 0.55 : 1)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
            startAssignment(manual: false)
        }
        .onDisappear {
            assignmentTask?.cancel()
            autoRetryTask?.cancel()
        }
    }

    private func startAssignment(manual: Bool) {
        guard !isCancelling else { return }
        if manual {
            autoRetryTask?.cancel()
        }
        assignmentTask?.cancel()
        assignmentTask = Task {
            await retryAssignment()
        }
    }

    private func retryAssignment() async {
        guard !isRetrying, !isCancelling else { return }
        await MainActor.run {
            isRetrying = true
            actionError = nil
        }
        defer {
            Task { @MainActor in
                isRetrying = false
            }
        }

        do {
            try await withTimeout(seconds: 20) {
                try await RideRepository().assignNearestDriver(rideId: ride.id)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                waitingForDrivers = false
                actionError = nil
            }
            autoRetryTask?.cancel()
        } catch is CancellationError {
            return
        } catch RideServiceError.noDrivers {
            guard !Task.isCancelled else { return }
            await MainActor.run { waitingForDrivers = true }
            scheduleAutoRetry()
        } catch {
            guard !Task.isCancelled else { return }
            let raw = String(describing: error).lowercased() + " " + error.localizedDescription.lowercased()
            if raw.contains("no_drivers") || raw.contains("no drivers") {
                await MainActor.run { waitingForDrivers = true }
                scheduleAutoRetry()
                return
            }
            await MainActor.run {
                waitingForDrivers = true
                actionError = AuthErrorMessages.message(for: error)
            }
            scheduleAutoRetry()
        }
    }

    private func scheduleAutoRetry() {
        autoRetryTask?.cancel()
        autoRetryTask = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled, !isCancelling else { return }
            await retryAssignment()
        }
    }

    private func cancelRide() async {
        guard !isCancelling else { return }
        await MainActor.run {
            isCancelling = true
            actionError = nil
        }
        assignmentTask?.cancel()
        autoRetryTask?.cancel()

        let customerId = appState.currentUser?.uid
            ?? Auth.auth().currentUser?.uid
        guard customerId != nil else {
            await MainActor.run {
                isCancelling = false
                actionError = L10n.string(.networkError, language: appState.language)
            }
            return
        }

        do {
            try await withTimeout(seconds: 20) {
                try await RideRepository().cancelRide(rideId: ride.id, cancelledBy: "customer")
            }
            await MainActor.run {
                isCancelling = false
                onSessionEnded?()
            }
        } catch {
            // If the ride is already cancelled / gone, leave the screen anyway.
            await MainActor.run {
                isCancelling = false
                onSessionEnded?()
            }
        }
    }

    private func withTimeout<T>(
        seconds: Double,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

struct DriverAssignedView: View {
    @EnvironmentObject private var appState: AppState
    let ride: Ride
    var onSessionEnded: (() -> Void)?

    @State private var driver: DriverProfile?
    @State private var driverTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(L10n.string(.driverAssignedTitle, language: appState.language))
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.navy)
                .padding(.top, AppSpacing.xl)

            if ride.driverId == nil {
                Spacer()
                SearchingPulseView(scale: 1.1)
                Text(L10n.string(.waitingDriverAccept, language: appState.language))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
                Spacer()
            } else {
                Spacer()

                driverProfileCard

                vehicleCard

                AppBanner(
                    message: L10n.string(.waitingDriverAccept, language: appState.language),
                    systemImage: "clock.fill",
                    tone: .info
                )
                .padding(.horizontal, AppSpacing.xl)

                Spacer()
            }

            Button {
                Task {
                    let customerId = appState.currentUser?.uid
                        ?? Auth.auth().currentUser?.uid
                    guard customerId != nil else { return }
                    try? await RideRepository().cancelRide(rideId: ride.id, cancelledBy: "customer")
                    onSessionEnded?()
                }
            } label: {
                Text(L10n.string(.cancelRide, language: appState.language))
            }
            .buttonStyle(SecondaryButtonStyle(destructive: true))
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
        .onAppear { startWatchingDriver() }
        .onDisappear {
            driverTask?.cancel()
            driverTask = nil
        }
        .onChange(of: ride.driverId) { _ in startWatchingDriver() }
    }

    private var driverProfileCard: some View {
        VStack(spacing: AppSpacing.md) {
            ProfileAvatarView(
                name: driver?.name ?? "",
                photoURL: driver?.profilePhotoUrl,
                size: 88
            )

            Text(driver?.name ?? L10n.string(.findingDriver, language: appState.language))
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandColors.navy)

            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Image(systemName: index < Int((driver?.rating ?? 5.0).rounded()) ? "star.fill" : "star")
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.gold)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .appCard()
        .padding(.horizontal, AppSpacing.xl)
    }

    private var vehicleCard: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "car.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.tealDark)
                    .frame(width: 36, height: 36)
                    .background(BrandColors.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(driver?.vehicleType ?? "—")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(BrandColors.navy)
                    if let color = driver?.vehicleColor, !color.isEmpty {
                        Text(color)
                            .font(.footnote)
                            .foregroundStyle(BrandColors.muted)
                    }
                }
                Spacer()
            }

            Divider()

            HStack(spacing: AppSpacing.md) {
                Image(systemName: "number")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.tealDark)
                    .frame(width: 36, height: 36)
                    .background(BrandColors.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadii.sm, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string(.vehiclePlate, language: appState.language))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(BrandColors.muted)
                    Text(driver?.vehiclePlate.isEmpty == false ? (driver?.vehiclePlate ?? "—") : "—")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BrandColors.navy)
                }
                Spacer()
            }
        }
        .appCard()
        .padding(.horizontal, AppSpacing.xl)
    }

    private func startWatchingDriver() {
        driverTask?.cancel()
        guard let driverId = ride.driverId else {
            driver = nil
            return
        }
        driverTask = Task {
            for await updated in DriverRepository().watchDriver(uid: driverId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { driver = updated }
            }
        }
    }
}

struct ActiveRideMapView: View {
    @EnvironmentObject private var appState: AppState
    let ride: Ride

    @State private var driverCoordinate: CLLocationCoordinate2D?
    @State private var driverHeading: Double = 0
    @State private var driverProfile: DriverProfile?
    @State private var routePath: [CLLocationCoordinate2D] = []
    @State private var etaMinutes: Int?
    @State private var distanceKm: Double?
    @State private var driverTask: Task<Void, Never>?
    @State private var showChat = false
    @State private var lastRouteRefresh: Date?
    @State private var recenterToken = 1

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if MapsConfig.isConfigured {
                    GoogleMapView(
                        cameraTarget: driverCoordinate ?? ride.pickupCoordinate,
                        zoom: 14,
                        pickup: MapPlace(label: ride.pickupLabel, coordinate: ride.pickupCoordinate),
                        destination: MapPlace(label: ride.destinationLabel, coordinate: ride.destinationCoordinate),
                        driverCoordinate: driverCoordinate,
                        driverHeading: driverHeading,
                        routePath: routePath,
                        recenterToken: recenterToken
                    )
                    .ignoresSafeArea()
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            recenterToken += 1
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(BrandColors.tealDark)
                                .frame(width: 48, height: 48)
                                .background(.white, in: Circle())
                                .shadow(color: BrandColors.navy.opacity(0.16), radius: 8, y: 3)
                        }
                        .accessibilityLabel(L10n.string(.myLocation, language: appState.language))
                        .padding(.trailing, AppSpacing.lg)
                        .padding(.bottom, 280)
                    }
                }

                VStack(spacing: 0) {
                    AppSheetHandle()
                        .padding(.top, AppSpacing.sm)

                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        HStack(spacing: AppSpacing.md) {
                            AsyncImage(url: URL(string: driverProfile?.profilePhotoUrl ?? "")) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .foregroundStyle(BrandColors.teal)
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(BrandColors.teal.opacity(0.2), lineWidth: 2)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(statusTitle)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(BrandColors.navy)
                                Text(driverProfile?.name ?? "—")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(BrandColors.navy)
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(BrandColors.gold)
                                        .font(.caption)
                                    Text(String(format: "%.1f", driverProfile?.rating ?? 5))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BrandColors.muted)
                                }
                            }
                            Spacer()

                            if let etaMinutes, let distanceKm {
                                etaBadge(minutes: etaMinutes, distanceKm: distanceKm)
                            }
                        }

                        HStack {
                            Text(formatIqd(ride.fareAmountIqd))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(BrandColors.tealDark)
                            Spacer()
                            Text(appState.language == .arabic ? "توك توك" : "Tuk-Tuk")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BrandColors.muted)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(BrandColors.surface, in: Capsule())
                        }

                        HStack(spacing: AppSpacing.sm) {
                            Button {
                                callDriver()
                            } label: {
                                Label(
                                    appState.language == .arabic ? "اتصال" : "Call",
                                    systemImage: "phone.fill"
                                )
                            }
                            .buttonStyle(SecondaryButtonStyle())

                            Button {
                                showChat = true
                            } label: {
                                Label(
                                    appState.language == .arabic ? "محادثة" : "Chat",
                                    systemImage: "message.fill"
                                )
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                }
                .background {
                    RoundedRectangle(cornerRadius: AppRadii.xl, style: .continuous)
                        .fill(.white)
                        .shadow(color: BrandColors.navy.opacity(0.12), radius: 24, y: -4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadii.xl, style: .continuous)
                        .stroke(BrandColors.border, lineWidth: 1)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
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
        .onChange(of: ride.status) { _ in
            refreshRouteIfNeeded()
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

    private func etaBadge(minutes: Int, distanceKm: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(minutes)")
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.tealDark)
            Text(appState.language == .arabic ? "دقيقة" : "min")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandColors.muted)
            Text(appState.language == .arabic
                 ? "\(String(format: "%.1f", distanceKm)) كم"
                 : "\(String(format: "%.1f", distanceKm)) km")
                .font(.caption2)
                .foregroundStyle(BrandColors.muted)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(BrandColors.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
    }

    private func callDriver() {
        let phone = driverProfile?.phone.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !phone.isEmpty, let url = URL(string: "tel://\(phone)") else { return }
        UIApplication.shared.open(url)
    }

    private func refreshRouteIfNeeded() {
        guard let driverCoordinate else { return }
        let now = Date()
        if let lastRouteRefresh, now.timeIntervalSince(lastRouteRefresh) < MapPresenceConfig.routeRefreshInterval {
            return
        }
        lastRouteRefresh = now
        let target = ride.status == .accepted || ride.status == .matched
            ? ride.pickupCoordinate
            : ride.destinationCoordinate
        let km = NearbyProvidersService.distanceKm(from: driverCoordinate, to: target)
        distanceKm = km
        etaMinutes = NearbyProvidersService.estimateMinutes(distanceKm: km)
        // Keep a straight fallback immediately, then upgrade to a road polyline.
        routePath = [driverCoordinate, target]
        let origin = driverCoordinate
        Task {
            let path = await DirectionsRouteService().routePath(from: origin, to: target)
            await MainActor.run {
                guard path.count >= 2 else { return }
                routePath = path
                if path.count > 2 {
                    var roadKm = 0.0
                    for i in 1..<path.count {
                        roadKm += NearbyProvidersService.distanceKm(from: path[i - 1], to: path[i])
                    }
                    if roadKm > 0 {
                        distanceKm = roadKm
                        etaMinutes = NearbyProvidersService.estimateMinutes(distanceKm: roadKm)
                    }
                }
            }
        }
    }

    private func startWatchingDriver() {
        driverTask?.cancel()
        guard let driverId = ride.driverId else {
            driverCoordinate = nil
            driverProfile = nil
            return
        }

        driverTask = Task {
            for await profile in DriverRepository().watchDriver(uid: driverId) {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    driverProfile = profile
                    if let lat = profile?.latitude, let lng = profile?.longitude {
                        driverCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        driverHeading = profile?.heading ?? 0
                        refreshRouteIfNeeded()
                    } else {
                        driverCoordinate = nil
                    }
                }
            }
        }
    }
}

private struct SearchingPulseView: View {
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .fill(BrandColors.teal.opacity(0.12))
                .frame(width: 120, height: 120)
                .scaleEffect(scale)

            Circle()
                .fill(BrandColors.teal.opacity(0.2))
                .frame(width: 88, height: 88)
                .scaleEffect(scale * 0.95)

            Image(systemName: "car.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(BrandColors.tealDark)
        }
        .frame(width: 120, height: 120)
    }
}

