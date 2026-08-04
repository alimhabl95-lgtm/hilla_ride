import SwiftUI

/// Store detail — categories, products, prices, discounts, images from Firestore.
struct BusinessStoreView: View {
    @EnvironmentObject private var appState: AppState
    let businessId: String

    @State private var business: BusinessPartner?
    @State private var categories: [BusinessCategory] = []
    @State private var products: [BusinessProduct] = []
    @State private var categoryFilter: String?
    @State private var cartQty: [String: Int] = [:]
    @State private var cartProducts: [String: BusinessProduct] = [:]
    @State private var placing = false
    @State private var statusMessage: String?
    @State private var businessTask: Task<Void, Never>?
    @State private var categoriesTask: Task<Void, Never>?
    @State private var productsTask: Task<Void, Never>?

    private let service = BusinessService()
    private var isAr: Bool { appState.language == .arabic }

    private var cartCount: Int {
        cartQty.values.reduce(0, +)
    }

    private var visibleProducts: [BusinessProduct] {
        products.filter { product in
            guard product.available else { return false }
            guard let categoryFilter else { return true }
            return product.categoryId == categoryFilter
        }
    }

    var body: some View {
        Group {
            if let business, business.status != "live" {
                Text(isAr ? "هذا المتجر غير مباشر حالياً" : "This store is not live right now")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if let business {
                        Text(
                            [
                                business.address,
                                String(format: "★ %.1f (%d)", business.rating, business.ratingCount)
                            ]
                            .filter { !$0.isEmpty }
                            .joined(separator: " • ")
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    categoryChips

                    List {
                        ForEach(visibleProducts) { product in
                            productRow(product)
                        }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if visibleProducts.isEmpty {
                            Text(isAr ? "لا منتجات متاحة" : "No products available")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(business?.name(language: appState.language) ?? (isAr ? "المتجر" : "Store"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if cartCount > 0 {
                Button {
                    Task { await checkout() }
                } label: {
                    Text(
                        placing
                            ? (isAr ? "جارٍ الطلب..." : "Placing...")
                            : (isAr ? "اطلب الآن (\(cartCount))" : "Place order (\(cartCount))")
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandColors.teal)
                .disabled(placing)
                .padding(12)
                .background(.ultraThinMaterial)
            }
        }
        .alert(
            isAr ? "الطلب" : "Order",
            isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
        .onAppear { startWatching() }
        .onDisappear {
            businessTask?.cancel()
            categoriesTask?.cancel()
            productsTask?.cancel()
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: isAr ? "الكل" : "All", selected: categoryFilter == nil) {
                    categoryFilter = nil
                }
                ForEach(categories.filter(\.active)) { category in
                    chip(
                        title: category.name(language: appState.language),
                        selected: categoryFilter == category.id
                    ) {
                        categoryFilter = category.id
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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

    private func productRow(_ product: BusinessProduct) -> some View {
        let qty = cartQty[product.id] ?? 0
        return HStack(spacing: 12) {
            productImage(url: product.imageUrl)
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name(language: appState.language))
                    .font(.headline)
                Text(priceLine(for: product))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button { adjust(product: product, delta: -1) } label: {
                    Image(systemName: "minus.circle")
                }
                .disabled(qty <= 0)

                Text("\(qty)")
                    .frame(minWidth: 18)

                Button { adjust(product: product, delta: 1) } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(BrandColors.tealDark)
        }
        .padding(.vertical, 4)
    }

    private func priceLine(for product: BusinessProduct) -> String {
        var parts = [money(product.effectivePriceIqd)]
        if product.discountPercent > 0 {
            parts.append("-\(Int(product.discountPercent))%")
        }
        parts.append("\(product.prepMinutes) \(isAr ? "د" : "min")")
        return parts.joined(separator: " • ")
    }

    private func money(_ amount: Int) -> String {
        isAr ? "\(amount) د.ع" : "\(amount) IQD"
    }

    @ViewBuilder
    private func productImage(url: String) -> some View {
        if let imageURL = URL(string: url), !url.isEmpty {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "fork.knife")
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
        }
    }

    private func adjust(product: BusinessProduct, delta: Int) {
        let next = max(0, (cartQty[product.id] ?? 0) + delta)
        if next == 0 {
            cartQty.removeValue(forKey: product.id)
            cartProducts.removeValue(forKey: product.id)
        } else {
            cartQty[product.id] = next
            cartProducts[product.id] = product
        }
    }

    private func startWatching() {
        businessTask?.cancel()
        categoriesTask?.cancel()
        productsTask?.cancel()
        businessTask = Task {
            for await item in service.watchBusiness(businessId: businessId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { business = item }
            }
        }
        categoriesTask = Task {
            for await items in service.watchCategories(businessId: businessId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { categories = items }
            }
        }
        productsTask = Task {
            for await items in service.watchProducts(businessId: businessId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { products = items }
            }
        }
    }

    private func checkout() async {
        placing = true
        defer { placing = false }
        do {
            guard let partner = try await service.fetchBusiness(businessId: businessId),
                  partner.status == "live"
            else {
                statusMessage = isAr ? "المتجر غير مباشر" : "Store is not live"
                return
            }
            let items: [BusinessOrderItem] = cartQty.compactMap { id, qty in
                guard let product = cartProducts[id] else { return nil }
                return BusinessOrderItem(
                    productId: id,
                    nameEn: product.nameEn,
                    nameAr: product.nameAr,
                    unitPriceIqd: product.effectivePriceIqd,
                    quantity: qty
                )
            }
            let orderId = try await service.placeOrder(
                businessId: businessId,
                items: items,
                dropoffLat: partner.latitude,
                dropoffLng: partner.longitude,
                dropoffLabel: isAr ? "عنوان التوصيل" : "Delivery address"
            )
            cartQty.removeAll()
            cartProducts.removeAll()
            statusMessage = isAr ? "تم إرسال الطلب: \(orderId)" : "Order placed: \(orderId)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
