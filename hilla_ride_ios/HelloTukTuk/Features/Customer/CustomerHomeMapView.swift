import CoreLocation
import SwiftUI

struct CustomerHomeMapView: View {
    @EnvironmentObject private var appState: AppState
    let user: AppUser

    @StateObject private var locationService = LocationService()
    @State private var selectedSubDistrictId = BabilRegions.customerDistrict.subDistricts[0].id
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

    private var subDistrict: BabilSubDistrict {
        BabilRegions.subDistrict(byId: selectedSubDistrictId)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if MapsConfig.isConfigured {
                    GoogleMapView(
                        cameraTarget: pickup?.coordinate ?? subDistrict.center,
                        zoom: 14,
                        pickup: pickup,
                        destination: destination,
                        onLongPress: { coordinate in
                            setDestination(at: coordinate)
                        }
                    )
                    .ignoresSafeArea(edges: .top)
                } else {
                    mapsUnavailableView
                }

                rideSearchPanel
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LanguageToggle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        CurrentRideIconButton(role: .customer)
                        AnnouncementIconButton(showAnnouncements: $showAnnouncements)
                        LegalDocumentsMenu()
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
                        Button {
                            showProfile = true
                        } label: {
                            Image(systemName: "person.circle")
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
                    radiusKm: 12,
                    onSelect: { place in
                        pickup = place
                    }
                )
            }
            .navigationDestination(isPresented: $showDestinationSearch) {
                PlaceSearchView(
                    title: L10n.string(.destinationLabel, language: appState.language),
                    center: destination?.coordinate ?? pickup?.coordinate ?? subDistrict.center,
                    radiusKm: 12,
                    onSelect: { place in
                        destination = place
                    }
                )
            }
            .navigationDestination(isPresented: $showPickupPinPicker) {
                MapPinPickerView(
                    title: L10n.string(.pickupLabel, language: appState.language),
                    initialCenter: pickup?.coordinate ?? subDistrict.center
                ) { place in
                    pickup = place
                }
            }
            .navigationDestination(isPresented: $showDestinationPinPicker) {
                MapPinPickerView(
                    title: L10n.string(.destinationLabel, language: appState.language),
                    initialCenter: destination?.coordinate ?? pickup?.coordinate ?? subDistrict.center
                ) { place in
                    destination = place
                }
            }
            .task {
                locationService.requestAuthorizationIfNeeded()
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
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(.customerHomeTitle, language: appState.language))
                .font(.headline)

            Picker(L10n.string(.subDistrict, language: appState.language), selection: $selectedSubDistrictId) {
                ForEach(BabilRegions.customerDistrict.subDistricts) { sub in
                    Text(sub.displayName(language: appState.language)).tag(sub.id)
                }
            }
            .pickerStyle(.menu)

            SavedPlacesBar { place in
                destination = place
            }

            Button {
                showPickupSearch = true
            } label: {
                locationRow(
                    icon: "circle.fill",
                    color: .green,
                    title: L10n.string(.pickupLabel, language: appState.language),
                    value: pickup?.label ?? L10n.string(.selectPickup, language: appState.language)
                )
            }
            .buttonStyle(.plain)
            Button(L10n.string(.pickOnMap, language: appState.language)) {
                showPickupPinPicker = true
            }
            .font(.caption)
            .buttonStyle(.borderless)

            Button {
                showDestinationSearch = true
            } label: {
                locationRow(
                    icon: "mappin.circle.fill",
                    color: .red,
                    title: L10n.string(.destinationLabel, language: appState.language),
                    value: destination?.label ?? L10n.string(.selectDestination, language: appState.language)
                )
            }
            .buttonStyle(.plain)
            Button(L10n.string(.pickOnMap, language: appState.language)) {
                showDestinationPinPicker = true
            }
            .font(.caption)
            .buttonStyle(.borderless)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button(L10n.string(.useMyLocation, language: appState.language)) {
                    useMyLocation()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button(L10n.string(.bookRide, language: appState.language)) {
                    attemptBookRide()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func locationRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(BrandColors.navy)
            }
            Spacer()
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
        }
    }

    private func useMyLocation() {
        errorMessage = nil
        if let coordinate = locationService.currentCoordinate {
            pickup = MapPlace(
                label: L10n.string(.myLocation, language: appState.language),
                coordinate: coordinate
            )
            return
        }
        locationService.refreshCurrentLocation()
        if let coordinate = locationService.currentCoordinate {
            pickup = MapPlace(
                label: L10n.string(.myLocation, language: appState.language),
                coordinate: coordinate
            )
        } else {
            errorMessage = L10n.string(.locationUnavailable, language: appState.language)
        }
    }

    private func setDestination(at coordinate: CLLocationCoordinate2D) {
        errorMessage = nil
        destination = MapPlace(
            label: L10n.string(.mapPinDestination, language: appState.language),
            coordinate: coordinate
        )
    }

    private func attemptBookRide() {
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
