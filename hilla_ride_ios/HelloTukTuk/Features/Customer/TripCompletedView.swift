import SwiftUI

struct TripCompletedView: View {
    @EnvironmentObject private var appState: AppState
    let rideId: String
    var onFinished: (() -> Void)?

    @State private var ride: Ride?
    @State private var selectedRating = 0
    @State private var feedback = ""
    @State private var isSubmitting = false
    @State private var rideTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text(L10n.string(.tripCompletedTitle, language: appState.language))
                    .font(.title.bold())

                if let ride {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(L10n.string(.pickupLabel, language: appState.language)): \(ride.pickupLabel)")
                        Text("\(L10n.string(.destinationLabel, language: appState.language)): \(ride.destinationLabel)")
                        Divider()
                        Text(formatIqd(ride.fareAmountIqd))
                            .font(.title.bold())
                        Text(L10n.string(.paymentMethodCash, language: appState.language))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))

                    if ride.driverRating != nil {
                        Text(L10n.string(.ratingSubmitted, language: appState.language))
                            .foregroundStyle(BrandColors.tealDark)
                    } else {
                        ratingSection
                    }
                } else {
                    ProgressView(L10n.string(.loading, language: appState.language))
                }

                Button(L10n.string(.done, language: appState.language)) {
                    onFinished?()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
        .onAppear { startWatchingRide() }
        .onDisappear {
            rideTask?.cancel()
        }
    }

    private var ratingSection: some View {
        VStack(spacing: 12) {
            Text(L10n.string(.rateYourDriver, language: appState.language))
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        selectedRating = star
                    } label: {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.title)
                            .foregroundStyle(BrandColors.gold)
                    }
                }
            }

            TextField(L10n.string(.feedbackOptional, language: appState.language), text: $feedback, axis: .vertical)
                .textFieldStyle(AppTextFieldStyle())

            Button(L10n.string(.submitRating, language: appState.language)) {
                Task { await submitRating() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedRating < 1 || isSubmitting)
        }
    }

    private func formatIqd(_ amount: Int) -> String {
        appState.language == .arabic ? "\(amount) د.ع" : "\(amount) IQD"
    }

    private func startWatchingRide() {
        rideTask = Task {
            for await updated in RideRepository().watchRide(rideId: rideId) {
                guard !Task.isCancelled else { break }
                await MainActor.run { ride = updated }
            }
        }
    }

    private func submitRating() async {
        guard let customerId = appState.currentUser?.uid else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        try? await RideRepository().submitDriverRating(
            rideId: rideId,
            customerId: customerId,
            rating: selectedRating,
            feedback: feedback
        )
    }
}
