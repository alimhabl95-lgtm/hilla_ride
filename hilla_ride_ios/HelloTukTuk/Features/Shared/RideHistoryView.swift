import SwiftUI

struct RideHistoryView: View {
    @EnvironmentObject private var appState: AppState
    let customerId: String?
    let driverId: String?
    var statusFilter: RideStatus?
    var title: String?

    @State private var rides: [Ride] = []
    @State private var historyTask: Task<Void, Never>?

    var body: some View {
        List(rides) { ride in
            VStack(alignment: .leading, spacing: 6) {
                if !ride.rideNumber.isEmpty {
                    Text(L10n.rideNumberLabel(ride.rideNumber, language: appState.language))
                        .font(.caption.bold())
                        .foregroundStyle(BrandColors.tealDark)
                }
                Text("\(ride.pickupLabel) → \(ride.destinationLabel)")
                    .font(.subheadline.bold())
                if let when = ride.completedAt ?? ride.createdAt {
                    Text("\(L10n.string(.tripDateTime, language: appState.language)): \(formattedDate(when))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(ride.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatIqd(ride.fareAmountIqd))
                    .font(.headline)
                    .foregroundStyle(BrandColors.tealDark)
                if ride.driverEarningsIqd > 0 {
                    Text("\(L10n.string(.driverNetEarnings, language: appState.language)): \(formatIqd(ride.driverEarningsIqd))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .overlay {
            if rides.isEmpty {
                Text(L10n.string(.noRideHistory, language: appState.language))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title ?? L10n.string(.rideHistoryTitle, language: appState.language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startWatching() }
        .onDisappear { historyTask?.cancel() }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: appState.language == .arabic ? "ar" : "en")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatIqd(_ amount: Int) -> String {
        appState.language == .arabic ? "\(amount) د.ع" : "\(amount) IQD"
    }

    private func startWatching() {
        historyTask = Task {
            let repository = RideRepository()
            let stream: AsyncStream<[Ride]>
            if let customerId {
                stream = repository.watchRideHistoryForCustomer(customerId: customerId, statusFilter: statusFilter)
            } else if let driverId {
                stream = repository.watchRideHistoryForDriver(driverId: driverId, statusFilter: statusFilter)
            } else {
                return
            }
            for await batch in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run { rides = batch }
            }
        }
    }
}
