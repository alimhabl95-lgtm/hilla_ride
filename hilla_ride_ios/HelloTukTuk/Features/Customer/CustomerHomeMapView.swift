import CoreLocation
import SwiftUI

struct CustomerHomeMapView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var areaCatalog = ServiceAreaCatalog.shared
    let user: AppUser

    @StateObject private var locationService = LocationService()
    @State private var selectedProvinceId = ""
    @State private var selectedDistrictId = ""
    @State private var selectedSubDistrictId = ""
    @State private var pickup: MapPlace?
    @State private var destination: MapPlace?
    @State private var showBookRide = false
    @State private var showProfile = false
    @State private var showPickupSearch = false
    @State private var showDestinationSearch = false
    @State private var showPickupPinPicker = false
    @State private var showDestinationPinPicker = false
    @State private var showHistory = false
    @State private var showSupport = false
    @State private var showAnnouncements = false
    @State private var showSavedPlaces = false
    @State private var showRewards = false
    @State private var errorMessage: String?
    @State private var nearbyDrivers: [MapDriverMarker] = []
    @State private var nearbyTask: Task<Void, Never>?
    @State private var cameraCenter: CLLocationCoordinate2D?
    /// Bump only for intentional camera moves (Recenter / booking place changes).
    /// Starts at 1 so the first updateUIView performs an initial framing.
    @State private var recenterToken = 1
    @State private var cameraTargetOverride: CLLocationCoordinate2D?
    @State private var preferTargetOnly = false
    /// Prevents area onChange handlers from wiping a place we just selected.
    @State private var suppressLocationClear = false

    private var hasSubDistrict: Bool {
        !selectedSubDistrictId.isEmpty
    }

    /// Districts under the currently selected governorate — dynamic, backed
    /// by the live catalog, so Admin-added districts appear automatically.
    private var districtsInSelectedProvince: [BabilDistrict] {
        BabilRegions.customerDistricts(forProvince: selectedProvinceId)
    }

    private var subDistrictsInSelectedDistrict: [BabilSubDistrict] {
        districtsInSelectedProvince.first { $0.id == selectedDistrictId }?.subDistricts ?? []
    }

    /// The chosen sub-district when one is selected; otherwise the first
    /// sub-district of the selected district, used only for camera framing
    /// (never for search/booking — those are gated by `hasSubDistrict`).
    private var subDistrict: BabilSubDistrict {
        if hasSubDistrict {
            return BabilRegions.subDistrict(byId: selectedSubDistrictId)
        }
        if let first = subDistrictsInSelectedDistrict.first {
            return first
        }
        return BabilRegions.customerDistrict.subDistricts.first
            ?? BabilRegions.seedDistricts[0].subDistricts[0]
    }

    private var regionLabel: String {
        hasSubDistrict ? subDistrict.displayName(language: appState.language) : ""
    }

    private var selectedDistrict: BabilDistrict? {
        districtsInSelectedProvince.first { $0.id == selectedDistrictId }
    }

    private var cityScopeLabel: String {
        if hasSubDistrict {
            return subDistrict.displayName(language: appState.language)
        }
        return selectedDistrict?.displayName(language: appState.language) ?? ""
    }

    private var districtDisplayName: String {
        selectedDistrict?.displayName(language: appState.language) ?? ""
    }

    private var districtSearchCenter: CLLocationCoordinate2D {
        let subs = subDistrictsInSelectedDistrict
        guard !subs.isEmpty else { return subDistrict.center }
        let lat = subs.map(\.center.latitude).reduce(0, +) / Double(subs.count)
        let lon = subs.map(\.center.longitude).reduce(0, +) / Double(subs.count)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var districtSearchBiasKm: Double {
        guard !selectedDistrictId.isEmpty else { return searchBiasRadiusKm }
        return BabilRegions.searchBiasRadiusKm(forDistrict: selectedDistrictId)
    }

    private var searchRadiusKm: Double {
        subDistrict.searchRadiusKm
    }

    private var searchBiasRadiusKm: Double {
        subDistrict.searchBiasRadiusKm
    }

    @discardableResult
    private func requireSubDistrict() -> Bool {
        if hasSubDistrict { return true }
        syncAreaSelection()
        if hasSubDistrict { return true }
        errorMessage = L10n.string(.selectSubDistrictFirst, language: appState.language)
        return false
    }

    private var mapCameraTarget: CLLocationCoordinate2D {
        cameraTargetOverride
            ?? pickup?.coordinate
            ?? locationService.currentCoordinate
            ?? subDistrict.center
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if MapsConfig.isConfigured {
                    GoogleMapView(
                        cameraTarget: mapCameraTarget,
                        zoom: 14,
                        pickup: pickup,
                        destination: destination,
                        nearbyDrivers: nearbyDrivers,
                        onLongPress: { coordinate in
                            setDestination(at: coordinate)
                        },
                        onCameraIdle: { coordinate in
                            cameraCenter = coordinate
                            if pickup == nil {
                                startNearbyWatch()
                            }
                        },
                        recenterToken: recenterToken,
                        preferTargetOnly: preferTargetOnly
                    )
                    .ignoresSafeArea(edges: .top)
                } else {
                    mapsUnavailableView
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: recenterToMyLocation) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(BrandColors.tealDark)
                                .frame(width: 48, height: 48)
                                .background(.white, in: Circle())
                                .shadow(color: BrandColors.navy.opacity(0.16), radius: 8, y: 3)
                        }
                        .accessibilityLabel(L10n.string(.myLocation, language: appState.language))
                        .padding(.trailing, AppSpacing.lg)
                        .padding(.bottom, 380)
                    }
                }

                rideSearchPanel
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LanguageToggle()
                        .tint(BrandColors.tealDark)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        CurrentRideIconButton(role: .customer)
                        customerOverflowMenu
                    }
                }
            }
            .navigationDestination(isPresented: $showBookRide) {
                if let pickup, let destination {
                    BookRideView(
                        user: user,
                        pickup: pickup,
                        destination: destination,
                        districtId: selectedDistrictId,
                        subDistrictId: selectedSubDistrictId
                    )
                }
            }
            .navigationDestination(isPresented: $showProfile) {
                ProfileView()
            }
            .navigationDestination(isPresented: $showHistory) {
                RideHistoryView(customerId: user.uid, driverId: nil)
            }
            .navigationDestination(isPresented: $showSupport) {
                SupportView()
            }
            .navigationDestination(isPresented: $showAnnouncements) {
                AnnouncementsView()
            }
            .navigationDestination(isPresented: $showSavedPlaces) {
                SavedPlacesManageView()
            }
            .navigationDestination(isPresented: $showRewards) {
                CustomerRewardsView(user: user)
            }
            .navigationDestination(isPresented: $showPickupPinPicker) {
                MapPinPickerView(
                    title: L10n.string(.pickupLabel, language: appState.language),
                    initialCenter: pickup?.coordinate ?? subDistrict.center,
                    subDistrictId: selectedSubDistrictId
                ) { place in
                    setPickup(place, recenter: true)
                }
            }
            .navigationDestination(isPresented: $showDestinationPinPicker) {
                MapPinPickerView(
                    title: L10n.string(.destinationLabel, language: appState.language),
                    initialCenter: destination?.coordinate ?? pickup?.coordinate ?? subDistrict.center,
                    subDistrictId: selectedSubDistrictId
                ) { place in
                    setDestinationPlace(place, recenter: true)
                }
            }
            .sheet(isPresented: $showPickupSearch) {
                NavigationStack {
                    PlaceSearchView(
                        title: L10n.string(.pickupLabel, language: appState.language),
                        center: hasSubDistrict ? subDistrict.center : districtSearchCenter,
                        radiusKm: hasSubDistrict ? subDistrict.searchRadiusKm : searchRadiusKm,
                        biasRadiusKm: hasSubDistrict
                            ? max(subDistrict.searchBiasRadiusKm, subDistrict.searchRadiusKm)
                            : districtSearchBiasKm,
                        districtId: selectedDistrictId,
                        regionLabel: hasSubDistrict
                            ? subDistrict.displayName(language: appState.language)
                            : districtDisplayName,
                        districtName: districtDisplayName,
                        subDistrictId: selectedSubDistrictId,
                        subDistrictName: hasSubDistrict
                            ? subDistrict.displayName(language: appState.language)
                            : "",
                        cityScopeLabel: hasSubDistrict
                            ? subDistrict.displayName(language: appState.language)
                            : cityScopeLabel,
                        boundary: hasSubDistrict ? subDistrict.boundary : nil,
                        onSelect: { place in
                            setPickup(place, recenter: true)
                            showPickupSearch = false
                        }
                    )
                    .environmentObject(appState)
                }
            }
            .sheet(isPresented: $showDestinationSearch) {
                NavigationStack {
                    PlaceSearchView(
                        title: L10n.string(.destinationLabel, language: appState.language),
                        center: hasSubDistrict ? subDistrict.center : districtSearchCenter,
                        radiusKm: hasSubDistrict ? subDistrict.searchRadiusKm : searchRadiusKm,
                        biasRadiusKm: hasSubDistrict
                            ? max(subDistrict.searchBiasRadiusKm, subDistrict.searchRadiusKm)
                            : districtSearchBiasKm,
                        districtId: selectedDistrictId,
                        regionLabel: hasSubDistrict
                            ? subDistrict.displayName(language: appState.language)
                            : districtDisplayName,
                        districtName: districtDisplayName,
                        subDistrictId: selectedSubDistrictId,
                        subDistrictName: hasSubDistrict
                            ? subDistrict.displayName(language: appState.language)
                            : "",
                        cityScopeLabel: hasSubDistrict
                            ? subDistrict.displayName(language: appState.language)
                            : cityScopeLabel,
                        boundary: hasSubDistrict ? subDistrict.boundary : nil,
                        onSelect: { place in
                            setDestinationPlace(place, recenter: true)
                            showDestinationSearch = false
                        }
                    )
                    .environmentObject(appState)
                }
            }
            .task {
                locationService.requestAuthorizationIfNeeded()
                startNearbyWatch()
                if selectedProvinceId.isEmpty {
                    selectedProvinceId = BabilRegions.customerProvinces.first?.id
                        ?? BabilRegions.seedProvinceId
                }
                if selectedDistrictId.isEmpty {
                    selectedDistrictId = BabilRegions.customerDistrictId
                }
                syncAreaSelection()
            }
            .onChange(of: pickup) { _ in startNearbyWatch() }
            .onChange(of: selectedProvinceId) { _ in
                guard !suppressLocationClear else { return }
                selectedDistrictId = districtsInSelectedProvince.first?.id ?? ""
            }
            .onChange(of: selectedDistrictId) { _ in
                guard !suppressLocationClear else {
                    startNearbyWatch()
                    return
                }
                if selectedSubDistrictId.isEmpty,
                   subDistrictsInSelectedDistrict.count == 1,
                   let only = subDistrictsInSelectedDistrict.first {
                    selectedSubDistrictId = only.id
                } else if !subDistrictsInSelectedDistrict.contains(where: { $0.id == selectedSubDistrictId }) {
                    selectedSubDistrictId = ""
                }
                errorMessage = nil
                clearLocationsOutsideSelectedArea()
                startNearbyWatch()
                requestRecenter(to: subDistrict.center, targetOnly: true)
            }
            .onChange(of: areaCatalog.synced) { _ in syncAreaSelection() }
            .onChange(of: areaCatalog.liveDistricts.map(\.id)) { _ in syncAreaSelection() }
            .onChange(of: selectedSubDistrictId) { _ in
                guard !suppressLocationClear else {
                    startNearbyWatch()
                    return
                }
                clearLocationsOutsideSelectedArea()
                startNearbyWatch()
                requestRecenter(to: subDistrict.center, targetOnly: true)
            }
            .onDisappear {
                nearbyTask?.cancel()
                nearbyTask = nil
            }
        }
    }

    private var nearbyCenter: CLLocationCoordinate2D {
        pickup?.coordinate ?? cameraCenter ?? subDistrict.center
    }

    private func startNearbyWatch() {
        nearbyTask?.cancel()
        let center = nearbyCenter
        nearbyTask = Task {
            let stream = NearbyProvidersService().watchNearbyAvailable(center: center)
            for await providers in stream {
                guard !Task.isCancelled else { break }
                let markers = providers.map {
                    MapDriverMarker(id: $0.providerId, coordinate: $0.coordinate, heading: $0.heading)
                }
                await MainActor.run { nearbyDrivers = markers }
            }
        }
    }

    private var customerOverflowMenu: some View {
        Menu {
            Button {
                showProfile = true
            } label: {
                Label(L10n.string(.profileTitle, language: appState.language), systemImage: "person.circle")
            }
            Button {
                showHistory = true
            } label: {
                Label(L10n.string(.rideHistoryTitle, language: appState.language), systemImage: "list.bullet.rectangle")
            }
            Button {
                showAnnouncements = true
            } label: {
                Label(L10n.string(.announcementsTitle, language: appState.language), systemImage: "bell")
            }
            Button {
                showRewards = true
            } label: {
                Label(
                    appState.language == .arabic ? "المكافآت" : "Rewards",
                    systemImage: "gift"
                )
            }
            Button {
                showSupport = true
            } label: {
                Label(L10n.string(.supportTitle, language: appState.language), systemImage: "headphones")
            }
            Button {
                showSavedPlaces = true
            } label: {
                Label(L10n.string(.savedPlacesTitle, language: appState.language), systemImage: "mappin.and.ellipse")
            }
            Button {
                showProfile = true
            } label: {
                Label(
                    appState.language == .arabic ? "الإعدادات" : "Settings",
                    systemImage: "gearshape"
                )
            }
            Link(destination: LegalConfig.privacyPolicyURL(languageCode: appState.language.rawValue)) {
                Label(L10n.string(.privacyPolicy, language: appState.language), systemImage: "lock.doc")
            }
            Divider()
            Button(role: .destructive) {
                Task { try? await appState.signOut() }
            } label: {
                Label(L10n.string(.logout, language: appState.language), systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(BrandColors.tealDark)
        }
        .accessibilityLabel(appState.language == .arabic ? "القائمة" : "Menu")
    }

    private var mapsUnavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(BrandColors.teal)
            Text(L10n.string(.mapsUnavailable, language: appState.language))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }

    private var rideSearchPanel: some View {
        VStack(spacing: 0) {
            AppSheetHandle()
                .padding(.top, AppSpacing.sm)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if user.hasPromoRemaining {
                    AppBanner(
                        message: L10n.customerPromoBanner(
                            code: user.promoCode,
                            remaining: user.promoRidesLimit - user.promoRidesUsed,
                            language: appState.language
                        ),
                        systemImage: "tag.fill",
                        tone: .info
                    )
                }

                Text(L10n.string(.bookRideTitle, language: appState.language))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BrandColors.navy)

                serviceAreaCard

                SavedPlacesBar { place in
                    setDestinationPlace(place, recenter: true)
                }

                tripPlannerCard

                if let errorMessage {
                    AppBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tone: .danger)
                }

                HStack(spacing: AppSpacing.sm) {
                    Button {
                        useMyLocation()
                    } label: {
                        Label(
                            L10n.string(.useMyLocation, language: appState.language),
                            systemImage: "location.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button(L10n.string(.bookRide, language: appState.language)) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        attemptBookRide()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .opacity(pickup != nil && destination != nil ? 1 : 0.55)
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

    /// Service area selection — governorate, district, and sub-district.
    private var serviceAreaCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Label {
                Text(L10n.string(.serviceAreaTitle, language: appState.language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)
            } icon: {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(BrandColors.tealDark)
            }

            areaSelector

            if hasSubDistrict {
                Text(L10n.searchLimitedToCity(cityScopeLabel, language: appState.language))
                    .font(.caption)
                    .foregroundStyle(BrandColors.tealDark)
                    .multilineTextAlignment(.leading)
            } else {
                Text(L10n.string(.selectSubDistrictFirst, language: appState.language))
                    .font(.caption)
                    .foregroundStyle(BrandColors.muted)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColors.surface, in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .stroke(BrandColors.border, lineWidth: 1)
        }
    }

    /// Pickup and destination rows in one card — Uber-style trip planner.
    private var tripPlannerCard: some View {
        VStack(spacing: 0) {
            tripRow(
                icon: "circle.fill",
                iconColor: BrandColors.success,
                title: L10n.string(.pickupLabel, language: appState.language),
                value: pickup?.label ?? L10n.string(.selectPickup, language: appState.language),
                isSet: pickup != nil,
                onSearch: { if requireSubDistrict() { showPickupSearch = true } },
                onPickMap: { if requireSubDistrict() { showPickupPinPicker = true } }
            )

            Divider()
                .padding(.leading, 52)

            tripRow(
                icon: "mappin.circle.fill",
                iconColor: BrandColors.danger,
                title: L10n.string(.destinationLabel, language: appState.language),
                value: destination?.label ?? L10n.string(.selectDestination, language: appState.language),
                isSet: destination != nil,
                onSearch: { if requireSubDistrict() { showDestinationSearch = true } },
                onPickMap: { if requireSubDistrict() { showDestinationPinPicker = true } }
            )
        }
        .background(.white, in: RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadii.lg, style: .continuous)
                .stroke(BrandColors.border, lineWidth: 1)
        }
    }

    private func tripRow(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        isSet: Bool,
        onSearch: @escaping () -> Void,
        onPickMap: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor, in: Circle())

            Button(action: onSearch) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandColors.muted)
                    Text(value)
                        .font(.body.weight(isSet ? .semibold : .regular))
                        .foregroundStyle(isSet ? BrandColors.navy : BrandColors.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onPickMap) {
                VStack(spacing: 2) {
                    Image(systemName: "scope")
                        .font(.body.weight(.semibold))
                    Text(L10n.string(.pickOnMapShort, language: appState.language))
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(BrandColors.tealDark)
                .frame(minWidth: 52, minHeight: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string(.pickOnMapShort, language: appState.language))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
    }

    /// Cascading Governorate → District → Sub-district selector. Iraq is
    /// fixed and never shown; all three levels are dynamic, backed by
    /// `ServiceAreaCatalog` (live Firestore data with a Babil seed fallback
    /// before the first sync), so Admin-added areas appear automatically.
    private var areaSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            let provinces = BabilRegions.customerProvinces
            HStack(spacing: AppSpacing.sm) {
                areaPicker(
                    label: L10n.string(.governorateLabel, language: appState.language),
                    selection: $selectedProvinceId,
                    options: provinces.map { ($0.id, $0.displayName(language: appState.language)) },
                    disabled: provinces.count <= 1
                )
                areaPicker(
                    label: L10n.string(.districtLabel, language: appState.language),
                    selection: $selectedDistrictId,
                    options: districtsInSelectedProvince.map {
                        ($0.id, $0.displayName(language: appState.language))
                    }
                )
            }

            areaPicker(
                label: L10n.string(.subDistrict, language: appState.language),
                selection: $selectedSubDistrictId,
                options: [("", L10n.string(.selectSubDistrictHint, language: appState.language))]
                    + subDistrictsInSelectedDistrict.map {
                        ($0.id, $0.displayName(language: appState.language))
                    }
            )
        }
    }

    private func areaPicker(
        label: String,
        selection: Binding<String>,
        options: [(String, String)],
        disabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(BrandColors.muted)
            Picker(label, selection: selection) {
                ForEach(options, id: \.0) { id, name in
                    Text(name).tag(id)
                }
            }
            .pickerStyle(.menu)
            .tint(BrandColors.tealDark)
            .disabled(disabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mapToolbarButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BrandColors.tealDark)
                .frame(width: 40, height: 40)
                .background(.white, in: Circle())
                .shadow(color: BrandColors.navy.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func syncAreaSelection() {
        let provinces = BabilRegions.customerProvinces
        if selectedProvinceId.isEmpty || !provinces.contains(where: { $0.id == selectedProvinceId }) {
            selectedProvinceId = provinces.first?.id ?? BabilRegions.seedProvinceId
        }

        let districts = districtsInSelectedProvince
        if districts.isEmpty {
            selectedDistrictId = BabilRegions.customerDistrictId
        } else if !districts.contains(where: { $0.id == selectedDistrictId }) {
            selectedDistrictId = districts.first?.id ?? BabilRegions.customerDistrictId
        }

        let subs = subDistrictsInSelectedDistrict
        if subs.count == 1, let only = subs.first {
            selectedSubDistrictId = only.id
        } else if !selectedSubDistrictId.isEmpty,
                  !subs.contains(where: { $0.id == selectedSubDistrictId }) {
            selectedSubDistrictId = ""
        }
    }

    private func requestRecenter(to coordinate: CLLocationCoordinate2D, targetOnly: Bool) {
        cameraTargetOverride = coordinate
        preferTargetOnly = targetOnly
        recenterToken += 1
    }

    /// Recenter camera to GPS only — does not change pickup/destination.
    private func recenterToMyLocation() {
        locationService.requestAuthorizationIfNeeded()
        locationService.refreshCurrentLocation()
        if let coordinate = locationService.currentCoordinate {
            requestRecenter(to: coordinate, targetOnly: true)
        } else if let pickup {
            requestRecenter(to: pickup.coordinate, targetOnly: true)
        } else {
            errorMessage = L10n.string(.locationUnavailable, language: appState.language)
        }
    }

    private func isWithinSelectedDistrict(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard !selectedDistrictId.isEmpty else { return false }
        return BabilRegions.isNearDistrictForSearch(
            districtId: selectedDistrictId,
            point: coordinate,
            extraBufferKm: 35
        )
    }

    @discardableResult
    private func guardSelectedArea(for coordinate: CLLocationCoordinate2D) -> Bool {
        // Soft district check — Admin sub-district polygons are often wrong/tight.
        guard isWithinSelectedDistrict(coordinate) || adoptPlaceArea(for: coordinate) else {
            errorMessage = L10n.string(.searchOutsideRegion, language: appState.language)
            return false
        }
        return true
    }

    private func clearLocationsOutsideSelectedArea() {
        guard !suppressLocationClear else { return }
        if let pickup, !isWithinSelectedDistrict(pickup.coordinate) {
            self.pickup = nil
        }
        if let destination, !isWithinSelectedDistrict(destination.coordinate) {
            self.destination = nil
        }
    }

    @discardableResult
    private func requireDistrict() -> Bool {
        syncAreaSelection()
        if !selectedDistrictId.isEmpty { return true }
        errorMessage = L10n.string(.selectSubDistrictFirst, language: appState.language)
        return false
    }

    /// Aligns governorate / district / area to a coordinate. Accepts any point
    /// inside the service catalog (or near it), instead of blocking the user.
    @discardableResult
    private func adoptPlaceArea(for coordinate: CLLocationCoordinate2D) -> Bool {
        let resolved = BabilRegions.resolveFromPoint(coordinate)

        // Prefer keeping the user's selected district when the point is near it.
        if !selectedDistrictId.isEmpty,
           BabilRegions.isNearDistrictForSearch(
               districtId: selectedDistrictId,
               point: coordinate,
               extraBufferKm: 35
           ) {
            if resolved.districtId == selectedDistrictId {
                selectedSubDistrictId = resolved.subDistrictId
            } else if let nearestInDistrict = subDistrictsInSelectedDistrict.min(by: {
                GeoMath.distanceKm(from: $0.center, to: coordinate)
                    < GeoMath.distanceKm(from: $1.center, to: coordinate)
            }) {
                selectedSubDistrictId = nearestInDistrict.id
            }
            selectedProvinceId = BabilRegions.provinceId(forDistrict: selectedDistrictId)
            return true
        }

        // Otherwise jump to the area that actually contains this point.
        if BabilRegions.isNearDistrictForSearch(
            districtId: resolved.districtId,
            point: coordinate,
            extraBufferKm: 35
        ) || ServiceAreaCatalog.shared.isWithinAnyActiveArea(coordinate) {
            selectedDistrictId = resolved.districtId
            selectedSubDistrictId = resolved.subDistrictId
            selectedProvinceId = BabilRegions.provinceId(forDistrict: resolved.districtId)
            return true
        }

        // Final safety net for Babil service footprint (search uses the same box).
        if (31.7...33.2).contains(coordinate.latitude),
           (43.8...45.4).contains(coordinate.longitude) {
            selectedDistrictId = resolved.districtId
            selectedSubDistrictId = resolved.subDistrictId
            selectedProvinceId = BabilRegions.provinceId(forDistrict: resolved.districtId)
            return true
        }

        errorMessage = L10n.string(.searchOutsideRegion, language: appState.language)
        return false
    }

    private func setPickup(_ place: MapPlace, recenter: Bool) {
        // Keep suppress true until after SwiftUI processes district/sub-district
        // onChange — a `defer` reset was clearing the place again immediately.
        suppressLocationClear = true

        // Always apply the tapped place first so the row never stays blank.
        errorMessage = nil
        pickup = place
        if !adoptPlaceArea(for: place.coordinate) {
            // Keep the place; only warn if far outside Babil.
            errorMessage = L10n.string(.searchOutsideRegion, language: appState.language)
        }
        if recenter {
            requestRecenter(to: place.coordinate, targetOnly: false)
        }
        releaseLocationClearSuppress()
    }

    private func setDestinationPlace(_ place: MapPlace, recenter: Bool) {
        suppressLocationClear = true

        errorMessage = nil
        destination = place
        if !adoptPlaceArea(for: place.coordinate) {
            errorMessage = L10n.string(.searchOutsideRegion, language: appState.language)
        }
        if recenter {
            requestRecenter(to: place.coordinate, targetOnly: false)
        }
        releaseLocationClearSuppress()
    }

    private func releaseLocationClearSuppress() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            suppressLocationClear = false
        }
    }

    private func useMyLocation() {
        errorMessage = nil
        locationService.requestAuthorizationIfNeeded()
        locationService.refreshCurrentLocation()
        if let coordinate = locationService.currentCoordinate {
            setPickup(
                MapPlace(
                    label: L10n.string(.myLocation, language: appState.language),
                    coordinate: coordinate
                ),
                recenter: true
            )
        } else {
            errorMessage = L10n.string(.locationUnavailable, language: appState.language)
        }
    }

    private func setDestination(at coordinate: CLLocationCoordinate2D) {
        setDestinationPlace(
            MapPlace(
                label: L10n.string(.mapPinDestination, language: appState.language),
                coordinate: coordinate
            ),
            recenter: true
        )
    }

    private func attemptBookRide() {
        errorMessage = nil
        guard let pickup else {
            errorMessage = L10n.string(.selectPickup, language: appState.language)
            return
        }
        guard let destination else {
            errorMessage = L10n.string(.selectDestination, language: appState.language)
            return
        }
        if !RideLocationRules.areDistinct(pickup.coordinate, destination.coordinate) {
            errorMessage = L10n.string(.pickupDestinationSame, language: appState.language)
            return
        }
        // Re-adopt areas from the chosen points so booking is not blocked by
        // a mismatched ناحية selection.
        guard adoptPlaceArea(for: pickup.coordinate),
              adoptPlaceArea(for: destination.coordinate) else {
            return
        }
        if selectedSubDistrictId.isEmpty {
            errorMessage = L10n.string(.selectSubDistrictFirst, language: appState.language)
            return
        }
        showBookRide = true
    }
}
