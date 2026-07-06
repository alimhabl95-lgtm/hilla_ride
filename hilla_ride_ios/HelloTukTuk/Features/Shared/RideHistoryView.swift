import SwiftUI

struct RideHistoryView: View {
    @EnvironmentObject private var appState: AppState
    let customerId: String?
    let driverId: String?

    @State private var rides: [Ride] = []
    @State private var historyTask: Task<Void, Never>?

    var body: some View {
        List(rides) { ride in
            VStack(alignment: .leading, spacing: 6) {
                Text("\(ride.pickupLabel) → \(ride.destinationLabel)")
                    .font(.subheadline.bold())
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
        .navigationTitle(L10n.string(.rideHistoryTitle, language: appState.language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startWatching() }
        .onDisappear { historyTask?.cancel() }
    }

    private func formatIqd(_ amount: Int) -> String {
        appState.language == .arabic ? "\(amount) د.ع" : "\(amount) IQD"
    }

    private func startWatching() {
        historyTask = Task {
            let repository = RideRepository()
            let stream: AsyncStream<[Ride]>
            if let customerId {
                stream = repository.watchRideHistoryForCustomer(customerId: customerId)
            } else if let driverId {
                stream = repository.watchRideHistoryForDriver(driverId: driverId)
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
