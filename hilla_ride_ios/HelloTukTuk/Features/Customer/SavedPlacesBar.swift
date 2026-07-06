import SwiftUI

struct SavedPlacesBar: View {
    @EnvironmentObject private var appState: AppState
    let onPlaceSelected: (MapPlace) -> Void

    @State private var places: [SavedPlace] = []
    @State private var placesTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(BrandColors.teal)
                Text(L10n.string(.savedPlacesTitle, language: appState.language))
                    .font(.subheadline.bold())
            }

            if places.isEmpty {
                Text(L10n.string(.savedPlacesEmptyHint, language: appState.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(places) { place in
                            Button {
                                onPlaceSelected(place.asMapPlace)
                            } label: {
                                Text(place.label)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(BrandColors.teal.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .contextMenu {
                                Button(L10n.string(.deleteSavedPlace, language: appState.language), role: .destructive) {
                                    Task { await deletePlace(place) }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { startWatching() }
        .onDisappear {
            placesTask?.cancel()
        }
    }

    private func startWatching() {
        guard let uid = appState.currentUser?.uid else { return }
        placesTask = Task {
            for await batch in SavedPlacesService().watchSavedPlaces(uid: uid) {
                guard !Task.isCancelled else { break }
                await MainActor.run { places = batch }
            }
        }
    }

    private func deletePlace(_ place: SavedPlace) async {
        guard let uid = appState.currentUser?.uid else { return }
        try? await SavedPlacesService().deleteSavedPlace(uid: uid, placeId: place.id)
    }
}
