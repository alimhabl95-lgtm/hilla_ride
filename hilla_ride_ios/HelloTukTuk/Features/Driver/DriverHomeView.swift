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
    @State private var showWallet = false
    @State private var walletConfig = WalletConfig.default
    @State private var walletConfigTask: Task<Void, Never>?
    @State private var monthlyStats: DriverMonthlyStats?
    @State private var statsTask: Task<Void, Never>?
    @State private var activeCustomer: AppUser?
    @State private var customerTask: Task<Void, Never>?
    @State private var cancelledCount = 0
    @State private var cancelledTask: Task<Void, Never>?
    @State private var onlinePulse = false

    private var currentDriver: DriverProfile {
        liveDriver ?? driver
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AnnouncementBannerView(audience: "drivers")
                Group {
                    if let ride = activeRide {
                        driverRidePanel(ride: ride)
                    } else {
                        idleDriverPanel
                    }
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
            .navigationDestination(isPresented: $showWallet) {
                DriverWalletView(driver: currentDriver)
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
                showWallet = true
            } label: {
                Label(
                    appState.language == .arabic ? "المحفظة" : "Wallet",
                    systemImage: "wallet.pass"
                )
            }
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
            VStack(spacing: AppSpacing.lg) {
                driverHeader

                walletCard

                availabilityCard

                if walletIsLow || walletIsBlocked {
                    walletBanner
                }

                todayStatsRow

                tripsStatsRow

                DriverDeliveryOrdersPanel(driverId: currentDriver.uid)

                if let monthlyStats {
                    monthlyPrizeCard(stats: monthlyStats)
                } else {
                    monthlyPrizeCard(
                        stats: DriverMonthlyStats(
                            rideCount: 0,
                            rank: 1,
                            totalDrivers: 0,
                            prizeAmountIqd: MonthlyPrizeConfig.defaultPrizeIqd,
                            monthKey: MonthlyPrizeConfig.currentMonthKey()
                        )
                    )
                    .redacted(reason: .placeholder)
                }

                earningsCard(driver: currentDriver)

                if let errorMessage {
                    AppBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tone: .danger)
                }
            }
            .padding(AppSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }

    private var driverHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))

            Text(currentDriver.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(BrandColors.navy)
        }
        .frame(maxWidth: .infinity)
    }

    private var walletCard: some View {
        AppWalletCard(
            title: appState.language == .arabic ? "رصيد المحفظة" : "Wallet balance",
            balance: formatIqd(currentDriver.walletBalanceIqd),
            subtitle: walletCardSubtitle,
            actionTitle: appState.language == .arabic ? "فتح المحفظة / شحن" : "Open wallet / recharge"
        ) {
            showWallet = true
        }
    }

    private var walletCardSubtitle: String? {
        if walletIsBlocked {
            return appState.language == .arabic
                ? "محظور — اشحن لاستقبال الرحلات"
                : "Blocked — recharge to receive trips"
        }
        if walletIsLow {
            return appState.language == .arabic ? "رصيد منخفض" : "Low balance"
        }
        return appState.language == .arabic ? "نشط" : "Active"
    }

    private var availabilityCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(currentDriver.isOnline ? BrandColors.success : BrandColors.muted)
                    .frame(width: 10, height: 10)
                    .overlay {
                        if currentDriver.isOnline {
                            Circle()
                                .stroke(BrandColors.success.opacity(0.35), lineWidth: 3)
                                .scaleEffect(onlinePulse ? 1.8 : 1)
                                .opacity(onlinePulse ? 0 : 0.8)
                        }
                    }

                Text(L10n.string(.driverAvailabilityTitle, language: appState.language))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(BrandColors.navy)
            }

            HStack(alignment: .center, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(
                        currentDriver.isOnline
                            ? L10n.string(.goOnline, language: appState.language)
                            : L10n.string(.goOffline, language: appState.language)
                    )
                    .font(.title3.weight(.bold))
                    .foregroundStyle(currentDriver.isOnline ? BrandColors.tealDark : BrandColors.muted)

                    Text(availabilityHint)
                        .font(.footnote)
                        .foregroundStyle(currentDriver.hasAssignedWorkArea ? BrandColors.muted : BrandColors.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.sm)

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
                .frame(minWidth: 51, minHeight: 48)
            }
            .padding(AppSpacing.md)
            .background(
                currentDriver.isOnline
                    ? BrandColors.teal.opacity(0.08)
                    : BrandColors.surface,
                in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
            )
        }
        .appCard()
        .onAppear {
            guard currentDriver.isOnline else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                onlinePulse = true
            }
        }
        .onChange(of: currentDriver.isOnline) { isOnline in
            if isOnline {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    onlinePulse = true
                }
            } else {
                onlinePulse = false
            }
        }
    }

    private var availabilityHint: String {
        if !currentDriver.hasAssignedWorkArea {
            return L10n.string(.driverWorkAreaRequired, language: appState.language)
        }
        return currentDriver.isOnline
            ? L10n.string(.driverWaitingForRequests, language: appState.language)
            : L10n.string(.driverGoOnlineHint, language: appState.language)
    }

    private var todayStatsRow: some View {
        HStack(spacing: AppSpacing.md) {
            AppStatCard(
                label: L10n.string(.monthlyRidesCount, language: appState.language),
                value: "\(currentDriver.monthlyRideCount)",
                systemImage: "car.fill"
            )

            AppStatCard(
                label: L10n.string(.driverNetEarnings, language: appState.language),
                value: formatIqd(currentDriver.outstandingDriverEarningsIqd),
                systemImage: "banknote.fill"
            )
        }
    }

    private var tripsStatsRow: some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                showCompletedHistory = true
            } label: {
                AppStatCard(
                    label: L10n.string(.completedRidesCount, language: appState.language),
                    value: "\(currentDriver.completedRidesCount)",
                    systemImage: "checkmark.circle.fill"
                )
            }
            .buttonStyle(.plain)

            Button {
                showCancelledHistory = true
            } label: {
                AppStatCard(
                    label: L10n.string(.cancelledRidesCount, language: appState.language),
                    value: "\(cancelledCount)",
                    systemImage: "xmark.circle.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func monthlyPrizeCard(stats: DriverMonthlyStats) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label(L10n.string(.driverMonthlyPrizeTitle, language: appState.language), systemImage: "trophy.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(BrandColors.gold)
            Text(L10n.driverMonthlyRideCount(stats.rideCount, language: appState.language))
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.navy)
            Text(L10n.driverMonthlyRank(stats.rank, stats.totalDrivers, language: appState.language))
                .font(.subheadline)
                .foregroundStyle(BrandColors.muted)
            Text(L10n.driverMonthlyPrizeAmount(formatIqd(stats.prizeAmountIqd), language: appState.language))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColors.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(BrandColors.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .stroke(BrandColors.gold.opacity(0.25), lineWidth: 1)
        }
    }

    private var walletIsBlocked: Bool {
        !currentDriver.walletAllowsMatching(minBalanceIqd: walletConfig.minBalanceIqd)
    }

    private var walletIsLow: Bool {
        currentDriver.walletBalanceIqd <= walletConfig.lowBalanceWarningIqd
    }

    private var walletBanner: some View {
        Button {
            showWallet = true
        } label: {
            AppBanner(
                message: walletIsBlocked
                    ? (appState.language == .arabic
                        ? "المحفظة محظورة — اشحن لاستقبال الرحلات. اضغط للشحن."
                        : "Wallet blocked — recharge to receive trips. Tap to recharge.")
                    : (appState.language == .arabic
                        ? "رصيد المحفظة منخفض. اضغط للشحن."
                        : "Wallet balance is low. Tap to recharge."),
                systemImage: "exclamationmark.triangle.fill",
                tone: walletIsBlocked ? .danger : .warning
            )
        }
        .buttonStyle(.plain)
    }

    private func earningsCard(driver: DriverProfile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.string(.yourEarningsTitle, language: appState.language))
                .font(.headline.weight(.bold))
                .foregroundStyle(BrandColors.navy)

            earningsRow(
                L10n.string(.monthlyRidesCount, language: appState.language),
                value: "\(driver.monthlyRideCount)",
                emphasized: true
            )
            earningsRow(
                L10n.string(.completedRidesCount, language: appState.language),
                value: "\(driver.completedRidesCount)"
            )
            earningsRow(
                L10n.string(.driverNetEarnings, language: appState.language),
                value: formatIqd(driver.outstandingDriverEarningsIqd)
            )
            earningsRow(
                L10n.string(.owedToPlatformLabel, language: appState.language),
                value: formatIqd(driver.outstandingPlatformCommissionIqd)
            )
            if driver.pendingBonusIqd > 0 {
                earningsRow(
                    L10n.string(.pendingBonusLabel, language: appState.language),
                    value: formatIqd(driver.pendingBonusIqd)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func earningsRow(_ label: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasized ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(BrandColors.muted)
            Spacer()
            Text(value)
                .font(emphasized ? .subheadline.weight(.bold) : .subheadline.weight(.medium))
                .foregroundStyle(BrandColors.navy)
        }
    }

    @ViewBuilder
    private func driverRidePanel(ride: Ride) -> some View {
        ZStack(alignment: .bottom) {
            if MapsConfig.isConfigured {
                GoogleMapView(
                    cameraTarget: ride.pickupCoordinate,
                    zoom: 14,
                    pickup: MapPlace(label: ride.pickupLabel, coordinate: ride.pickupCoordinate),
                    destination: MapPlace(label: ride.destinationLabel, coordinate: ride.destinationCoordinate)
                )
                .ignoresSafeArea()
            } else {
                BrandColors.surface.ignoresSafeArea()
            }

            driverRideBottomPanel(ride: ride)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }

    @ViewBuilder
    private func driverRideBottomPanel(ride: Ride) -> some View {
        VStack(spacing: 0) {
            AppSheetHandle()
                .padding(.top, AppSpacing.sm)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    ProfileAvatarView(
                        name: activeCustomer?.name ?? "",
                        photoURL: activeCustomer?.profilePhotoUrl,
                        size: 56
                    )
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(rideStatusTitle(ride.status))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(BrandColors.navy)
                        if let name = activeCustomer?.name, !name.isEmpty {
                            Text(name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BrandColors.muted)
                        }
                    }
                    Spacer(minLength: AppSpacing.sm)

                    Text(formatIqd(ride.fareAmountIqd))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BrandColors.tealDark)
                }

                tripLocationRow(
                    icon: "circle.fill",
                    iconColor: BrandColors.success,
                    title: appState.language == .arabic ? "من" : "Pickup",
                    label: ride.pickupLabel
                )
                tripLocationRow(
                    icon: "flag.fill",
                    iconColor: BrandColors.danger,
                    title: appState.language == .arabic ? "إلى" : "Destination",
                    label: ride.destinationLabel
                )

                if ride.status == .matched {
                    offerUrgencyBanner
                }

                Button {
                    showChat = true
                } label: {
                    Label(L10n.string(.messageCustomer, language: appState.language), systemImage: "message.fill")
                }
                .buttonStyle(SecondaryButtonStyle())

                rideActions(for: ride)

                if let errorMessage {
                    AppBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tone: .danger)
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

    private var offerUrgencyBanner: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .stroke(BrandColors.teal.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Image(systemName: "clock.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BrandColors.tealDark)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(appState.language == .arabic ? "عرض جديد" : "New offer")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(BrandColors.navy)
                Text(
                    appState.language == .arabic
                        ? "اقبل أو ارفض قبل انتهاء المهلة"
                        : "Accept or reject before time runs out"
                )
                .font(.caption)
                .foregroundStyle(BrandColors.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(BrandColors.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                .stroke(BrandColors.teal.opacity(0.2), lineWidth: 1)
        }
    }

    private func tripLocationRow(icon: String, iconColor: Color, title: String, label: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
                .background(iconColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColors.muted)
                Text(label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BrandColors.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func rideActions(for ride: Ride) -> some View {
        switch ride.status {
        case .matched:
            HStack(spacing: AppSpacing.md) {
                Button(L10n.string(.rejectRide, language: appState.language)) {
                    Task { await reject(ride) }
                }
                .buttonStyle(SecondaryButtonStyle(destructive: true))

                Button(L10n.string(.acceptRide, language: appState.language)) {
                    Task { await accept(ride) }
                }
                .buttonStyle(PrimaryButtonStyle())
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
        walletConfigTask = Task {
            for await config in WalletService().watchConfig() {
                guard !Task.isCancelled else { break }
                await MainActor.run { walletConfig = config }
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
        walletConfigTask?.cancel()
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
