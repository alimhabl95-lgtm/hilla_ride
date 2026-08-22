import CoreLocation
import SwiftUI
import UIKit

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
    @State private var pendingRideActions = Set<String>()

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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    CurrentRideIconButton(role: .driver)
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
        .onReceive(NotificationCenter.default.publisher(for: .navigateToCurrentRide)) { _ in
            // Driver home already shows activeRide when present; ensure watchers are live.
            if activeRide == nil {
                startWatching()
            }
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

                availabilityCard

                walletCard

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
            .padding(AppSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [BrandColors.surface, Color.white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var driverHeader: some View {
        HStack(spacing: AppSpacing.md) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.language == .arabic ? "مرحباً" : "Welcome")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BrandColors.muted)
                Text(currentDriver.name.isEmpty
                     ? (appState.language == .arabic ? "حساب السائق" : "Driver")
                     : currentDriver.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BrandColors.navy)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                showWallet = true
            } label: {
                Image(systemName: "wallet.pass.fill")
                    .font(.title3)
                    .foregroundStyle(BrandColors.tealDark)
                    .frame(width: 44, height: 44)
                    .background(BrandColors.teal.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .frame(width: 12, height: 12)
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

                Spacer()

                Text(
                    currentDriver.isOnline
                        ? (appState.language == .arabic ? "متصل" : "Online")
                        : (appState.language == .arabic ? "غير متصل" : "Offline")
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(currentDriver.isOnline ? BrandColors.success : BrandColors.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    (currentDriver.isOnline ? BrandColors.success : BrandColors.muted).opacity(0.12),
                    in: Capsule()
                )
            }

            Text(availabilityHint)
                .font(.subheadline)
                .foregroundStyle(currentDriver.hasAssignedWorkArea ? BrandColors.muted : BrandColors.danger)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if currentDriver.isOnline {
                    Button {
                        Task { await setOnline(false) }
                    } label: {
                        HStack {
                            Image(systemName: "pause.circle.fill")
                            Text(appState.language == .arabic ? "إيقاف العمل" : "Go offline")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button {
                        Task { await setOnline(true) }
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text(appState.language == .arabic ? "ابدأ استقبال الطلبات" : "Go online")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .disabled(isUpdatingOnline || !currentDriver.hasAssignedWorkArea)
            .opacity((isUpdatingOnline || !currentDriver.hasAssignedWorkArea) ? 0.55 : 1)
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
                label: appState.language == .arabic ? "رصيد المحفظة" : "Wallet balance",
                value: formatIqd(currentDriver.walletBalanceIqd),
                systemImage: "creditcard.fill"
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
        DriverActiveRideMapPanel(
            ride: ride,
            driverCoordinate: currentDriver.sortCoordinate,
            driverHeading: currentDriver.heading,
            customerCoordinate: activeCustomer?.coordinate
        ) {
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

            ScrollView {
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

                    if ride.status == .matched {
                        offerUrgencyBanner
                        rideActions(for: ride)
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

                    if ride.status != .matched {
                        rideActions(for: ride)
                    }

                    Button {
                        showChat = true
                    } label: {
                        Label(L10n.string(.messageCustomer, language: appState.language), systemImage: "message.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if let errorMessage {
                        AppBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tone: .danger)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
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
                rideActionButton(
                    rideId: ride.id,
                    action: "reject",
                    title: L10n.string(.rejectRide, language: appState.language),
                    style: .secondaryDestructive
                ) {
                    try await RideRepository().rejectRide(rideId: ride.id, driverId: driver.uid)
                }

                rideActionButton(
                    rideId: ride.id,
                    action: "accept",
                    title: L10n.string(.acceptRide, language: appState.language),
                    style: .primary
                ) {
                    try await RideRepository().acceptRide(rideId: ride.id, driverId: driver.uid)
                }
            }
        case .accepted:
            rideActionButton(
                rideId: ride.id,
                action: "start",
                title: L10n.string(.startRide, language: appState.language),
                style: .primary
            ) {
                try await RideRepository().startRide(rideId: ride.id)
            }
        case .inProgress:
            rideActionButton(
                rideId: ride.id,
                action: "end",
                title: L10n.string(.endRide, language: appState.language),
                style: .primary
            ) {
                try await RideRepository().endRideAwaitingCash(rideId: ride.id)
            }
        case .awaitingCashPayment:
            rideActionButton(
                rideId: ride.id,
                action: "cash",
                title: L10n.string(.confirmCashCollected, language: appState.language),
                style: .primary
            ) {
                try await RideRepository().confirmCashCollected(rideId: ride.id)
            }
        default:
            EmptyView()
        }
    }

    private enum RideActionStyle {
        case primary
        case secondaryDestructive
    }

    @ViewBuilder
    private func rideActionButton(
        rideId: String,
        action: String,
        title: String,
        style: RideActionStyle,
        task: @escaping () async throws -> Void
    ) -> some View {
        let pending = isRideActionPending(rideId: rideId, action: action)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await runRideAction(rideId: rideId, action: action, task: task) }
        } label: {
            Group {
                if pending {
                    ProgressView()
                        .tint(style == .primary ? .white : BrandColors.danger)
                        .frame(maxWidth: .infinity, minHeight: 54)
                } else {
                    Text(title)
                }
            }
        }
        .disabled(pending)
        .modifier(RideActionButtonStyleModifier(style: style))
    }

    private struct RideActionButtonStyleModifier: ViewModifier {
        let style: RideActionStyle

        func body(content: Content) -> some View {
            switch style {
            case .primary:
                content.buttonStyle(PrimaryButtonStyle())
            case .secondaryDestructive:
                content.buttonStyle(SecondaryButtonStyle(destructive: true))
            }
        }
    }

    private func rideActionKey(rideId: String, action: String) -> String {
        "\(rideId):\(action)"
    }

    private func isRideActionPending(rideId: String, action: String) -> Bool {
        pendingRideActions.contains(rideActionKey(rideId: rideId, action: action))
    }

    private func runRideAction(
        rideId: String,
        action: String,
        task: @escaping () async throws -> Void
    ) async {
        let key = rideActionKey(rideId: rideId, action: action)
        guard !pendingRideActions.contains(key) else { return }
        pendingRideActions.insert(key)
        defer { pendingRideActions.remove(key) }
        errorMessage = nil
        do {
            try await task()
        } catch {
            errorMessage = error.localizedDescription
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
}

/// Active-ride map with one-shot recenter (markers/routes update without moving camera).
private struct DriverActiveRideMapPanel<Bottom: View>: View {
    @EnvironmentObject private var appState: AppState
    let ride: Ride
    var driverCoordinate: CLLocationCoordinate2D?
    var driverHeading: Double = 0
    var customerCoordinate: CLLocationCoordinate2D?
    @ViewBuilder var bottom: () -> Bottom

    @State private var recenterToken = 1
    @State private var routePath: [CLLocationCoordinate2D] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            if MapsConfig.isConfigured {
                GoogleMapView(
                    cameraTarget: driverCoordinate ?? customerCoordinate ?? ride.pickupCoordinate,
                    zoom: 14,
                    pickup: MapPlace(
                        label: ride.pickupLabel,
                        coordinate: customerCoordinate ?? ride.pickupCoordinate
                    ),
                    destination: MapPlace(
                        label: ride.destinationLabel,
                        coordinate: ride.destinationCoordinate
                    ),
                    driverCoordinate: driverCoordinate,
                    driverHeading: driverHeading,
                    routePath: routePath,
                    recenterToken: recenterToken
                )
                .ignoresSafeArea()
            } else {
                BrandColors.surface.ignoresSafeArea()
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

            bottom()
        }
        .task(id: "\(ride.id)-\(ride.status.rawValue)-\(driverCoordinate?.latitude ?? 0)-\(customerCoordinate?.latitude ?? 0)") {
            let from = driverCoordinate ?? ride.pickupCoordinate
            let to: CLLocationCoordinate2D = {
                switch ride.status {
                case .accepted, .matched:
                    return customerCoordinate ?? ride.pickupCoordinate
                default:
                    return ride.destinationCoordinate
                }
            }()
            routePath = [from, to]
            let path = await DirectionsRouteService().routePath(from: from, to: to)
            if path.count >= 2 {
                routePath = path
            }
        }
    }
}
