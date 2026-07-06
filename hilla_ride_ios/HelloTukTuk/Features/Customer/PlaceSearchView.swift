import CoreLocation
import SwiftUI

struct PlaceSearchView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let title: String
    let center: CLLocationCoordinate2D
    let radiusKm: Double
    let onSelect: (MapPlace) -> Void

    @State private var query = ""
    @State private var results: [PlacesSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var savedMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            TextField(L10n.string(.searchPlacesHint, language: appState.language), text: $query)
                .textFieldStyle(AppTextFieldStyle())
                .padding()
                .onChange(of: query) { _, newValue in
                    scheduleSearch(query: newValue)
                }

            if isSearching {
                ProgressView()
                    .padding()
            }

            List(results) { result in
                HStack {
                    Button {
                        onSelect(result.asMapPlace)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.label)
                                .font(.body)
                                .foregroundStyle(BrandColors.navy)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        Task { await savePlace(result) }
                    } label: {
                        Image(systemName: "bookmark")
                    }
                }
            }
            .listStyle(.plain)

            if let savedMessage {
                Text(savedMessage)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.tealDark)
                    .padding(.horizontal)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearching = true }
            let places = await GooglePlacesService().searchPlaces(
                query: trimmed,
                center: center,
                radiusKm: radiusKm,
                languageCode: appState.language.rawValue
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                results = places
                isSearching = false
            }
        }
    }

    private func savePlace(_ result: PlacesSearchResult) async {
        guard let uid = appState.currentUser?.uid else { return }
        do {
            _ = try await SavedPlacesService().addSavedPlace(
                uid: uid,
                label: result.label,
                latitude: result.latitude,
                longitude: result.longitude
            )
            savedMessage = L10n.string(.savedPlaceAdded, language: appState.language)
        } catch {
            savedMessage = error.localizedDescription
        }
    }
}
