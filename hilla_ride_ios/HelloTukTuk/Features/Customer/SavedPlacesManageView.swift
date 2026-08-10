import SwiftUI

struct SavedPlacesManageView: View {
    @EnvironmentObject private var appState: AppState
    @State private var places: [SavedPlace] = []
    @State private var task: Task<Void, Never>?

    var body: some View {
        Group {
            if places.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(BrandColors.teal)
                    Text(L10n.string(.savedPlacesEmptyHint, language: appState.language))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(places) { place in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.label)
                                .font(.body.weight(.semibold))
                            Text(String(format: "%.5f, %.5f", place.latitude, place.longitude))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(L10n.string(.savedPlacesTitle, language: appState.language))
        .navigationBarTitleDisplayMode(.inline)
        .task { startWatch() }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func startWatch() {
        task?.cancel()
        guard let uid = appState.currentUser?.uid else { return }
        task = Task {
            for await batch in SavedPlacesService().watchSavedPlaces(uid: uid) {
                guard !Task.isCancelled else { break }
                await MainActor.run { places = batch }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        guard let uid = appState.currentUser?.uid else { return }
        for index in offsets {
            let place = places[index]
            Task {
                try? await SavedPlacesService().deleteSavedPlace(uid: uid, placeId: place.id)
            }
        }
    }
}
