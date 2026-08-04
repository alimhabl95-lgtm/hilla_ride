import SwiftUI

/// Live delivery offers — appears instantly when a business marks Ready.
struct DriverDeliveryOrdersPanel: View {
    @EnvironmentObject private var appState: AppState
    let driverId: String

    @State private var orders: [BusinessOrder] = []
    @State private var task: Task<Void, Never>?
    @State private var busyOrderId: String?
    @State private var errorMessage: String?

    private let service = BusinessService()
    private var isAr: Bool { appState.language == .arabic }

    var body: some View {
        Group {
            if !orders.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(isAr ? "طلبات توصيل جاهزة" : "Ready Delivery Orders")
                        .font(.headline)
                        .foregroundStyle(BrandColors.navy)

                    ForEach(orders.prefix(8)) { order in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.businessName.isEmpty ? order.businessId : order.businessName)
                                    .font(.subheadline.weight(.semibold))
                                Text(
                                    [
                                        order.dropoffLabel,
                                        money(order.deliveryFeeIqd),
                                        order.status.rawValue
                                    ]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " • ")
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if order.status == .ready {
                                Button {
                                    Task { await take(order) }
                                } label: {
                                    if busyOrderId == order.id {
                                        ProgressView()
                                    } else {
                                        Text(isAr ? "استلام التوصيل" : "Take Delivery")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(BrandColors.teal)
                                .disabled(busyOrderId != nil)
                            } else {
                                Text(isAr ? "قيد التوصيل" : "Out for delivery")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandColors.tealDark)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onAppear { startWatching() }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    private func money(_ amount: Int) -> String {
        isAr ? "\(amount) د.ع" : "\(amount) IQD"
    }

    private func startWatching() {
        task?.cancel()
        task = Task {
            for await items in service.watchDriverDeliveryOffers(driverId: driverId) {
                guard !Task.isCancelled else { break }
                let filtered = items.filter {
                    $0.status == .ready
                        || ($0.status == .outForDelivery && $0.driverId == driverId)
                }
                await MainActor.run { orders = filtered }
            }
        }
    }

    private func take(_ order: BusinessOrder) async {
        busyOrderId = order.id
        defer { busyOrderId = nil }
        do {
            try await service.updateOrderStatus(
                orderId: order.id,
                status: .outForDelivery,
                driverId: driverId
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
