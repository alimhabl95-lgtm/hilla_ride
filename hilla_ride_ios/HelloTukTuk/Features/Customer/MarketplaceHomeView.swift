import SwiftUI

/// Live marketplace — all data from Firestore, no hardcoded businesses.
struct MarketplaceHomeView: View {
    @EnvironmentObject private var appState: AppState

    @State private var types: [BusinessTypeConfig] = []
    @State private var businesses: [BusinessPartner] = []
    @State private var typeFilter: String?
    @State private var favoriteIds: Set<String> = []
    @State private var typesTask: Task<Void, Never>?
    @State private var businessesTask: Task<Void, Never>?
    @State private var favoritesTask: Task<Void, Never>?

    private let service = BusinessService()
    private let savedPlacesService = SavedPlacesService()
    private var isAr: Bool { appState.language == .arabic }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typeChips
                businessesList
            }
            .background(BrandColors.surface.ignoresSafeArea())
            .navigationTitle(isAr ? "المتاجر والخدمات" : "Stores & services")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { businessId in
                BusinessStoreView(businessId: businessId)
                    .environmentObject(appState)
            }
        }
        .onAppear {
            startWatchingTypes()
            startWatchingBusinesses()
            startWatchingFavorites()
        }
        .onDisappear {
            typesTask?.cancel()
            businessesTask?.cancel()
            favoritesTask?.cancel()
        }
        .onChange(of: typeFilter) { _ in
            startWatchingBusinesses()
        }
    }

    private var typeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: isAr ? "الكل" : "All", selected: typeFilter == nil) {
                    typeFilter = nil
                }
                ForEach(types) { type in
                    chip(
                        title: type.name(language: appState.language),
                        selected: typeFilter == type.id
                    ) {
                        typeFilter = type.id
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? BrandColors.teal : Color.white.opacity(0.7))
                .foregroundStyle(selected ? Color.white : BrandColors.navy)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var businessesList: some View {
        if businesses.isEmpty {
            AppEmptyState(
                title: isAr ? "لا متاجر مباشرة حالياً" : "No live businesses yet",
                message: isAr
                    ? "ستظهر تلقائياً عند موافقة الإدارة"
                    : "They appear automatically when approved",
                systemImage: "storefront"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(businesses) { business in
                        HStack(spacing: 8) {
                            NavigationLink(value: business.id) {
                                HStack(spacing: 12) {
                                    asyncLogo(url: business.logoUrl)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(business.name(language: appState.language))
                                            .font(.headline)
                                            .foregroundStyle(BrandColors.navy)
                                        Text(
                                            [
                                                business.typeId,
                                                business.address,
                                                String(format: "★ %.1f", business.rating)
                                            ]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " • ")
                                        )
                                        .font(.footnote)
                                        .foregroundStyle(BrandColors.muted)
                                        .lineLimit(2)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.forward")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(BrandColors.tealDark)
                                }
                                .frame(minHeight: 48)
                            }
                            .buttonStyle(.plain)

                            Button {
                                Task { await toggleFavorite(business.id) }
                            } label: {
                                Image(systemName: favoriteIds.contains(business.id) ? "heart.fill" : "heart")
                                    .foregroundStyle(favoriteIds.contains(business.id) ? .red : BrandColors.muted)
                            }
                            .buttonStyle(.plain)
                        }
                        .appCard()
                    }
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func asyncLogo(url: String) -> some View {
        if let logoURL = URL(string: url), !url.isEmpty {
            AsyncImage(url: logoURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "storefront.fill")
                        .foregroundStyle(BrandColors.tealDark)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            Image(systemName: "storefront.fill")
                .foregroundStyle(BrandColors.tealDark)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white.opacity(0.8)))
        }
    }

    private func startWatchingTypes() {
        typesTask?.cancel()
        typesTask = Task {
            for await items in service.watchBusinessTypes() {
                guard !Task.isCancelled else { break }
                await MainActor.run { types = items }
            }
        }
    }

    private func startWatchingBusinesses() {
        businessesTask?.cancel()
        businessesTask = Task {
            for await items in service.watchLiveBusinesses(typeId: typeFilter) {
                guard !Task.isCancelled else { break }
                await MainActor.run { businesses = items }
            }
        }
    }

    private func startWatchingFavorites() {
        favoritesTask?.cancel()
        guard let uid = appState.currentUser?.uid else { return }
        favoritesTask = Task {
            for await ids in savedPlacesService.watchFavoriteBusinessIds(uid: uid) {
                guard !Task.isCancelled else { break }
                await MainActor.run { favoriteIds = ids }
            }
        }
    }

    private func toggleFavorite(_ businessId: String) async {
        guard let uid = appState.currentUser?.uid else { return }
        do {
            _ = try await savedPlacesService.toggleFavoriteBusiness(uid: uid, businessId: businessId)
        } catch {
            // Best-effort toggle.
        }
    }
}
