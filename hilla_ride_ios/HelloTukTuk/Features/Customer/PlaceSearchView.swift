import CoreLocation
import SwiftUI

struct PlaceSearchView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let title: String
    let center: CLLocationCoordinate2D
    let radiusKm: Double
    var biasRadiusKm: Double = 0
    var districtId: String = ""
    var regionLabel: String = ""
    var districtName: String = ""
    var subDistrictName: String = ""
    var cityScopeLabel: String = ""
    var boundary: [CLLocationCoordinate2D]? = nil
    let onSelect: (MapPlace) -> Void

    @State private var query = ""
    @State private var results: [PlacesSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var savedMessage: String?
    @State private var statusMessage: String?
    @FocusState private var searchFocused: Bool
    private let searchService = PlaceSearchService()

    var body: some View {
        VStack(spacing: 0) {
            if !cityScopeLabel.isEmpty {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "location.circle.fill")
                        .foregroundStyle(BrandColors.tealDark)
                    Text(L10n.searchLimitedToCity(cityScopeLabel, language: appState.language))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(BrandColors.navy)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
                .background(BrandColors.surface)
            }

            HStack(spacing: AppSpacing.sm) {
                TextField(
                    cityScopeLabel.isEmpty
                        ? L10n.string(.searchPlacesHint, language: appState.language)
                        : L10n.searchPlacesInCity(cityScopeLabel, language: appState.language),
                    text: $query
                )
                .textFieldStyle(AppTextFieldStyle())
                .focused($searchFocused)
                .submitLabel(.search)
                .onSubmit { runSearch(immediate: true) }

                Button(L10n.string(.searchAction, language: appState.language)) {
                    runSearch(immediate: true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(BrandColors.tealDark, in: RoundedRectangle(cornerRadius: AppRadii.md, style: .continuous))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let savedMessage {
                Text(savedMessage)
                    .font(.footnote)
                    .foregroundStyle(BrandColors.tealDark)
                    .padding(.horizontal)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.string(.cancel, language: appState.language)) {
                    dismiss()
                }
            }
        }
        .onAppear {
            searchFocused = true
        }
    }

    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minQueryLength(for: trimmed) else {
            results = []
            statusMessage = nil
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func runSearch(immediate: Bool) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minQueryLength(for: trimmed) else {
            results = []
            statusMessage = nil
            isSearching = false
            return
        }
        searchTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ trimmed: String) async {
        await MainActor.run { isSearching = true }

        let places = await searchService.search(
            query: trimmed,
            center: center,
            radiusKm: radiusKm,
            biasRadiusKm: biasRadiusKm > 0 ? biasRadiusKm : max(radiusKm, 35),
            languageCode: appState.language.rawValue,
            regionLabel: regionLabel,
            districtId: districtId,
            districtName: districtName,
            subDistrictName: subDistrictName,
            boundary: boundary
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

    private var queryMeetsMinLength: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= minQueryLength(for: trimmed)
    }

    private func minQueryLength(for text: String) -> Int {
        text.unicodeScalars.contains(where: { (0x0600...0x06FF).contains($0.value) }) ? 1 : 2
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
        default:
            if cityScopeLabel.isEmpty {
                return isAr
                    ? "لا توجد نتائج في المنطقة المحددة"
                    : "No results in the selected area."
            }
            return isAr
                ? "لا توجد نتائج داخل \(cityScopeLabel)"
                : "No results inside \(cityScopeLabel)."
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
