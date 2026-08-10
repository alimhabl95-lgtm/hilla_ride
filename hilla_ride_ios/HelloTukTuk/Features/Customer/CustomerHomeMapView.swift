import CoreLocation
import SwiftUI

struct CustomerHomeMapView: View {
    @EnvironmentObject private var appState: AppState
    let user: AppUser

    @StateObject private var locationService = LocationService()
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

    private var subDistrict: BabilSubDistrict {
        BabilRegions.subDistrict(byId: selectedSubDistrictId)
    }

    private var regionLabel: String {
        hasSubDistrict ? subDistrict.displayName(language: appState.language) : ""
    }

    @discardableResult
    private func requireSubDistrict() -> Bool {
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
                    HStack(spacing: 4) {
                        CurrentRideIconButton(role: .customer)
                        AnnouncementIconButton(showAnnouncements: $showAnnouncements)
                        LegalDocumentsMenu()
                        mapToolbarButton(systemImage: "list.bullet.rectangle") {
                            showHistory = true
                        }
                        mapToolbarButton(systemImage: "headphones") {
                            showSupport = true
                        }
                        mapToolbarButton(systemImage: "person.circle.fill") {
                            showProfile = true
                        }
                    }
                }
            }
            .navigationDestination(isPresented: $showBookRide) {
                if let pickup, let destination {
                    BookRideView(
                        user: user,
                        pickup: pickup,
                        destination: destination,
                        districtId: BabilRegions.customerDistrictId,
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
            .navigationDestination(isPresented: $showPickupSearch) {
                PlaceSearchView(
                    title: L10n.string(.pickupLabel, language: appState.language),
                    center: subDistrict.center,
                    radiusKm: subDistrict.searchRadiusKm,
                    subDistrictId: selectedSubDistrictId,
                    regionLabel: regionLabel,
                    onSelect: { place in
                        setPickup(place, recenter: true)
                    }
                )
            }
            .navigationDestination(isPresented: $showDestinationSearch) {
                PlaceSearchView(
                    title: L10n.string(.destinationLabel, language: appState.language),
                    center: subDistrict.center,
                    radiusKm: subDistrict.searchRadiusKm,
                    subDistrictId: selectedSubDistrictId,
                    regionLabel: regionLabel,
                    onSelect: { place in
                        setDestinationPlace(place, recenter: true)
                    }
                )
            }
            .navigationDestination(isPresented: $showPickupPinPicker) {
                MapPinPickerView(
                    title: L10n.string(.pickupLabel, language: appState.language),
                    initialCenter: pickup?.coordinate ?? subDistrict.center
                ) { place in
                    setPickup(place, recenter: true)
                }
            }
            .navigationDestination(isPresented: $showDestinationPinPicker) {
                MapPinPickerView(
                    title: L10n.string(.destinationLabel, language: appState.language),
                    initialCenter: destination?.coordinate ?? pickup?.coordinate ?? subDistrict.center
                ) { place in
                    setDestinationPlace(place, recenter: true)
                }
            }
            .task {
                locationService.requestAuthorizationIfNeeded()
                startNearbyWatch()
            }
            .onChange(of: pickup) { _ in startNearbyWatch() }
            .onChange(of: selectedSubDistrictId) { _ in
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
                    Picker(L10n.string(.subDistrict, language: appState.language), selection: $selectedSubDistrictId) {
                        Text(L10n.string(.selectSubDistrictHint, language: appState.language)).tag("")
                        ForEach(BabilRegions.customerDistrict.subDistricts) { sub in
                            Text(sub.displayName(language: appState.language)).tag(sub.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(BrandColors.tealDark)
                    .onChange(of: selectedSubDistrictId) { _ in errorMessage = nil }
                }

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

    private func setPickup(_ place: MapPlace, recenter: Bool) {
        pickup = place
        if recenter {
            requestRecenter(to: place.coordinate, targetOnly: false)
        }
    }

    private func setDestinationPlace(_ place: MapPlace, recenter: Bool) {
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
        errorMessage = nil
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
        guard pickup != nil else {
            errorMessage = L10n.string(.selectPickup, language: appState.language)
            return
        }
        guard destination != nil else {
            errorMessage = L10n.string(.selectDestination, language: appState.language)
            return
        }
        if let pickup, let destination,
           !RideLocationRules.areDistinct(pickup.coordinate, destination.coordinate) {
            errorMessage = L10n.string(.pickupDestinationSame, language: appState.language)
            return
        }
        showBookRide = true
    }
}
