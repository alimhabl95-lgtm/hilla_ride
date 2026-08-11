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
                        .padding(.bottom, 340)
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
                        center: subDistrict.center,
                        radiusKm: subDistrict.searchBiasRadiusKm,
                        subDistrictId: selectedSubDistrictId,
                        regionLabel: regionLabel,
                        onSelect: { place in
                            setPickup(place, recenter: true)
                        }
                    )
                    .environmentObject(appState)
                }
            }
            .sheet(isPresented: $showDestinationSearch) {
                NavigationStack {
                    PlaceSearchView(
                        title: L10n.string(.destinationLabel, language: appState.language),
                        center: subDistrict.center,
                        radiusKm: subDistrict.searchBiasRadiusKm,
                        subDistrictId: selectedSubDistrictId,
                        regionLabel: regionLabel,
                        onSelect: { place in
                            setDestinationPlace(place, recenter: true)
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
                // Governorate switch always resets to that governorate's
                // first district; the sub-district reset below then forces
                // the customer to confirm the new area before booking.
                selectedDistrictId = districtsInSelectedProvince.first?.id ?? ""
            }
            .onChange(of: selectedDistrictId) { _ in
                if selectedSubDistrictId.isEmpty,
                   subDistrictsInSelectedDistrict.count == 1,
                   let only = subDistrictsInSelectedDistrict.first {
                    selectedSubDistrictId = only.id
                } else {
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
                clearLocationsOutsideSelectedArea()
                startNearbyWatch()
                // Region change is intentional booking context — one camera move.
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

                HStack {
                    Text(L10n.string(.customerHomeTitle, language: appState.language))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(BrandColors.navy)
                    Spacer()
                }

                areaSelector

                SavedPlacesBar { place in
                    if requireSubDistrict() {
                        setDestinationPlace(place, recenter: true)
                    }
                }

                VStack(spacing: AppSpacing.sm) {
                    locationCard(
                        icon: "circle.fill",
                        iconColor: BrandColors.success,
                        title: L10n.string(.pickupLabel, language: appState.language),
                        value: pickup?.label ?? L10n.string(.selectPickup, language: appState.language),
                        onSearch: { if requireSubDistrict() { showPickupSearch = true } },
                        onPickMap: { if requireSubDistrict() { showPickupPinPicker = true } }
                    )

                    locationConnector

                    locationCard(
                        icon: "mappin.circle.fill",
                        iconColor: BrandColors.danger,
                        title: L10n.string(.destinationLabel, language: appState.language),
                        value: destination?.label ?? L10n.string(.selectDestination, language: appState.language),
                        onSearch: { if requireSubDistrict() { showDestinationSearch = true } },
                        onPickMap: { if requireSubDistrict() { showDestinationPinPicker = true } }
                    )
                }

                if let errorMessage {
                    AppBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tone: .danger)
                }

                HStack(spacing: AppSpacing.md) {
                    Button(L10n.string(.useMyLocation, language: appState.language)) {
                        useMyLocation()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(L10n.string(.bookRide, language: appState.language)) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            attemptBookRide()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
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

    /// Cascading Governorate → District → Sub-district selector. Iraq is
    /// fixed and never shown; all three levels are dynamic, backed by
    /// `ServiceAreaCatalog` (live Firestore data with a Babil seed fallback
    /// before the first sync), so Admin-added areas appear automatically.
    private var areaSelector: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                let provinces = BabilRegions.customerProvinces
                Picker(L10n.string(.governorateLabel, language: appState.language), selection: $selectedProvinceId) {
                    ForEach(provinces) { province in
                        Text(province.displayName(language: appState.language)).tag(province.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(BrandColors.tealDark)
                .disabled(provinces.count <= 1)

                Picker(L10n.string(.districtLabel, language: appState.language), selection: $selectedDistrictId) {
                    ForEach(districtsInSelectedProvince) { district in
                        Text(district.displayName(language: appState.language)).tag(district.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(BrandColors.tealDark)
            }

            Picker(L10n.string(.subDistrict, language: appState.language), selection: $selectedSubDistrictId) {
                Text(L10n.string(.selectSubDistrictHint, language: appState.language)).tag("")
                ForEach(subDistrictsInSelectedDistrict) { sub in
                    Text(sub.displayName(language: appState.language)).tag(sub.id)
                }
            }
            .pickerStyle(.menu)
            .tint(BrandColors.tealDark)
        }
    }

    private var locationConnector: some View {
        HStack(spacing: AppSpacing.sm) {
            Rectangle()
                .fill(BrandColors.border)
                .frame(width: 2, height: 16)
                .padding(.leading, 21)
            Spacer()
        }
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

    private func locationCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        onSearch: @escaping () -> Void,
        onPickMap: @escaping () -> Void
    ) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Button(action: onSearch) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(iconColor, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BrandColors.muted)
                        Text(value)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .foregroundStyle(BrandColors.navy)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: AppSpacing.sm)

                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColors.tealDark)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(BrandColors.surface, in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous)
                        .stroke(BrandColors.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Button(L10n.string(.pickOnMap, language: appState.language), action: onPickMap)
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandColors.tealDark)
                .frame(minHeight: 44, alignment: .leading)
                .buttonStyle(.plain)
        }
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

    private func isWithinSelectedArea(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard hasSubDistrict else { return false }
        return BabilRegions.isWithin(subDistrictId: selectedSubDistrictId, point: coordinate)
    }

    @discardableResult
    private func guardSelectedArea(for coordinate: CLLocationCoordinate2D) -> Bool {
        guard isWithinSelectedArea(coordinate) else {
            errorMessage = L10n.string(.searchOutsideRegion, language: appState.language)
            return false
        }
        return true
    }

    private func clearLocationsOutsideSelectedArea() {
        if let pickup, !isWithinSelectedArea(pickup.coordinate) {
            self.pickup = nil
        }
        if let destination, !isWithinSelectedArea(destination.coordinate) {
            self.destination = nil
        }
    }

    private func setPickup(_ place: MapPlace, recenter: Bool) {
        guard guardSelectedArea(for: place.coordinate) else { return }
        errorMessage = nil
        pickup = place
        if recenter {
            requestRecenter(to: place.coordinate, targetOnly: false)
        }
    }

    private func setDestinationPlace(_ place: MapPlace, recenter: Bool) {
        guard guardSelectedArea(for: place.coordinate) else { return }
        errorMessage = nil
        destination = place
        if recenter {
            requestRecenter(to: place.coordinate, targetOnly: false)
        }
    }

    private func useMyLocation() {
        guard requireSubDistrict() else { return }
        errorMessage = nil
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
        guard requireSubDistrict() else { return }
        setDestinationPlace(
            MapPlace(
                label: L10n.string(.mapPinDestination, language: appState.language),
                coordinate: coordinate
            ),
            recenter: true
        )
    }

    private func attemptBookRide() {
        guard requireSubDistrict() else { return }
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
        guard guardSelectedArea(for: pickup.coordinate),
              guardSelectedArea(for: destination.coordinate) else {
            return
        }
        showBookRide = true
    }
}
