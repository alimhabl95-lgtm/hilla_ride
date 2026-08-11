import CoreLocation
import SwiftUI

struct MapPinPickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let title: String
    let initialCenter: CLLocationCoordinate2D
    var subDistrictId: String = ""
    let onConfirm: (MapPlace) -> Void

    @State private var mapCenter: CLLocationCoordinate2D
    @State private var label = ""
    @State private var isLoadingLabel = false
    @State private var labelTask: Task<Void, Never>?
    @State private var outsideRegionMessage: String?

    init(
        title: String,
        initialCenter: CLLocationCoordinate2D,
        subDistrictId: String = "",
        onConfirm: @escaping (MapPlace) -> Void
    ) {
        self.title = title
        self.initialCenter = initialCenter
        self.subDistrictId = subDistrictId
        self.onConfirm = onConfirm
        _mapCenter = State(initialValue: initialCenter)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if MapsConfig.isConfigured {
                    GoogleMapView(
                        cameraTarget: mapCenter,
                        zoom: 16,
                        onCameraIdle: { coordinate in
                            mapCenter = coordinate
                            outsideRegionMessage = nil
                            scheduleLabelLoad(for: coordinate)
                        },
                        pinPickerMode: true
                    )
                }

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.red)
                    .shadow(radius: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                if isLoadingLabel {
                    ProgressView()
                } else {
                    Text(label.isEmpty ? L10n.string(.loading, language: appState.language) : label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                if let outsideRegionMessage {
                    Text(outsideRegionMessage)
                        .font(.footnote)
                        .foregroundStyle(BrandColors.danger)
                }
                Button(L10n.string(.confirmPinLocation, language: appState.language)) {
                    confirmSelection()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            scheduleLabelLoad(for: mapCenter)
        }
        .onDisappear {
            labelTask?.cancel()
        }
    }

    private func confirmSelection() {
        // Soft check only — parent screen will adopt the correct district/area.
        if !subDistrictId.isEmpty {
            let sub = BabilRegions.subDistrict(byId: subDistrictId)
            let nearSub = GeoMath.distanceKm(from: sub.center, to: mapCenter)
                <= max(sub.searchRadiusKm, 20) + 35
            let inBabil = (31.7...33.2).contains(mapCenter.latitude)
                && (43.8...45.4).contains(mapCenter.longitude)
            if !nearSub && !inBabil {
                outsideRegionMessage = L10n.string(.searchOutsideRegion, language: appState.language)
                return
            }
        }
        let place = MapPlace(
            label: label.isEmpty ? L10n.string(.mapPinDestination, language: appState.language) : label,
            coordinate: mapCenter
        )
        onConfirm(place)
        dismiss()
    }

    private func scheduleLabelLoad(for coordinate: CLLocationCoordinate2D) {
        labelTask?.cancel()
        labelTask = Task {
            await MainActor.run { isLoadingLabel = true }
            let resolved = await GeocodingService().reverseGeocode(
                coordinate,
                languageCode: appState.language.rawValue
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                label = resolved
                isLoadingLabel = false
            }
        }
    }
}
