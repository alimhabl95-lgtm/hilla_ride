import CoreLocation
import SwiftUI

struct PlaceSearchView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let title: String
    let center: CLLocationCoordinate2D
    let radiusKm: Double
    var subDistrictId: String = ""
    var regionLabel: String = ""
    let onSelect: (MapPlace) -> Void

    @State private var query = ""
    @State private var results: [PlacesSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var savedMessage: String?
    @State private var statusMessage: String?
    private let searchService = PlaceSearchService()

    var body: some View {
        VStack(spacing: 0) {
            TextField(L10n.string(.searchPlacesHint, language: appState.language), text: $query)
                .textFieldStyle(AppTextFieldStyle())
                .padding()
                .onChange(of: query) { newValue in
                    scheduleSearch(query: newValue)
                }

            if isSearching {
                ProgressView()
                    .padding(.vertical, 8)
            }

            if let statusMessage, results.isEmpty, !isSearching, queryMeetsMinLength {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button {
                        Task { await savePlace(result) }
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel(L10n.string(.savedPlacesTitle, language: appState.language))
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
        let minLength = trimmed.unicodeScalars.contains(where: { (0x0600...0x06FF).contains($0.value) }) ? 1 : 2
        guard trimmed.count >= minLength else {
            results = []
            statusMessage = nil
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearching = true }
            let places = await searchService.search(
                query: trimmed,
                center: center,
                radiusKm: radiusKm,
                languageCode: appState.language.rawValue,
                regionLabel: regionLabel,
                subDistrictId: subDistrictId
            )
            guard !Task.isCancelled else { return }
            await MainActor.run {
                results = places
                isSearching = false
                if places.isEmpty {
                    statusMessage = emptyStateMessage(for: searchService.lastStatusMessage)
                } else {
                    statusMessage = nil
                }
            }
        }
    }

    private var queryMeetsMinLength: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let minLength = trimmed.unicodeScalars.contains(where: { (0x0600...0x06FF).contains($0.value) }) ? 1 : 2
        return trimmed.count >= minLength
    }

    private func emptyStateMessage(for code: String?) -> String {
        let isAr = appState.language == .arabic
        switch code {
        case "apiDenied":
            return isAr
                ? "تعذر الوصول إلى خدمة البحث. حاول مرة أخرى أو اختر الموقع من الخريطة."
                : "Place search is unavailable. Try again or pick on the map."
        case "network":
            return isAr
                ? "فشل الاتصال بخدمة البحث. تحقق من الإنترنت وحاول مجدداً."
                : "Could not reach place search. Check your connection and retry."
        case "no_results_in_area":
            return isAr
                ? "لا توجد نتائج في المنطقة المحددة"
                : "No results in the selected area."
        default:
            return isAr
                ? "لا توجد نتائج في المنطقة المحددة"
                : "No results in the selected area."
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
