import SwiftUI

struct BookRideView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let user: AppUser
    let pickup: MapPlace
    let destination: MapPlace
    let districtId: String
    let subDistrictId: String

    @State private var quote: RideQuote?
    @State private var isLoadingQuote = true
    @State private var isBooking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string(.bookRideTitle, language: appState.language))
                    .font(.largeTitle.bold())

                summaryRow(
                    title: L10n.string(.pickupLabel, language: appState.language),
                    value: pickup.label
                )
                summaryRow(
                    title: L10n.string(.destinationLabel, language: appState.language),
                    value: destination.label
                )

                if isLoadingQuote {
                    ProgressView(L10n.string(.loading, language: appState.language))
                } else if let quote {
                    if quote.outOfService {
                        Text(L10n.string(.outOfService, language: appState.language))
                            .foregroundStyle(.red)
                    } else {
                        summaryRow(
                            title: L10n.string(.distance, language: appState.language),
                            value: String(format: "%.1f km", quote.distanceKm)
                        )
                        summaryRow(
                            title: L10n.string(.estimatedFare, language: appState.language),
                            value: formatIqd(quote.fareIqd ?? 0)
                        )
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(L10n.string(.confirmBooking, language: appState.language)) {
                    Task { await bookRide() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoadingQuote || isBooking || quote?.canBook != true)
            }
            .padding(24)
        }
        .background(BrandColors.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            LoadingOverlay(isLoading: isBooking)
        }
        .task {
            await loadQuote()
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatIqd(_ amount: Int) -> String {
        if appState.language == .arabic {
            return "\(amount) د.ع"
        }
        return "\(amount) IQD"
    }

    private func loadQuote() async {
        isLoadingQuote = true
        defer { isLoadingQuote = false }

        let pricing = PricingService()
        quote = await pricing.quoteRide(
            pickup: pickup.coordinate,
            destination: destination.coordinate,
            districtId: districtId,
            subDistrictId: subDistrictId
        )
    }

    private func bookRide() async {
        guard let quote, let fare = quote.fareIqd else { return }
        errorMessage = nil
        isBooking = true
        defer { isBooking = false }

        do {
            let repository = RideRepository()
            _ = try await repository.bookRide(
                customerId: user.uid,
                pickup: pickup,
                destination: destination,
                districtId: districtId,
                subDistrictId: subDistrictId,
                fareAmountIqd: fare,
                distanceKm: quote.distanceKm
            )
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
