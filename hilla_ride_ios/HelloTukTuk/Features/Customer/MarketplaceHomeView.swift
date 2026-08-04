import SwiftUI

/// Live marketplace — all data from Firestore, no hardcoded businesses.
struct MarketplaceHomeView: View {
    @EnvironmentObject private var appState: AppState

    @State private var types: [BusinessTypeConfig] = []
    @State private var businesses: [BusinessPartner] = []
    @State private var typeFilter: String?
    @State private var typesTask: Task<Void, Never>?
    @State private var businessesTask: Task<Void, Never>?

    private let service = BusinessService()
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
        }
        .onDisappear {
            typesTask?.cancel()
            businessesTask?.cancel()
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
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "storefront")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text(isAr ? "لا متاجر مباشرة حالياً" : "No live businesses yet")
                    .font(.headline)
                Text(
                    isAr
                        ? "ستظهر تلقائياً عند موافقة الإدارة"
                        : "They appear automatically when approved"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(businesses) { business in
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
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
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
}
