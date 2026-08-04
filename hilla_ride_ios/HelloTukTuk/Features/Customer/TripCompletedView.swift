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
            VStack(spacing: 0) {
                AppSheetHandle()
                    .padding(.top, AppSpacing.sm)

                VStack(spacing: AppSpacing.xl) {
                    completionHeader

                    if let ride {
                        tripSummaryCard(ride: ride)

                        if ride.driverRating != nil {
                            AppBanner(
                                message: L10n.string(.ratingSubmitted, language: appState.language),
                                systemImage: "checkmark.circle.fill",
                                tone: .success
                            )
                        } else {
                            ratingSection
                        }
                    } else {
                        ProgressView(L10n.string(.loading, language: appState.language))
                            .padding(AppSpacing.xxl)
                    }

                    Button(L10n.string(.done, language: appState.language)) {
                        onFinished?()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
        .onAppear { startWatchingRide() }
        .onDisappear {
            rideTask?.cancel()
        }
    }

    private var completionHeader: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(BrandColors.success.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(BrandColors.success)
            }

            Text(L10n.string(.tripCompletedTitle, language: appState.language))
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.navy)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.md)
    }

    private func tripSummaryCard(ride: Ride) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            summaryRow(
                icon: "circle.fill",
                iconColor: BrandColors.success,
                label: L10n.string(.pickupLabel, language: appState.language),
                value: ride.pickupLabel
            )

            summaryRow(
                icon: "mappin.circle.fill",
                iconColor: BrandColors.danger,
                label: L10n.string(.destinationLabel, language: appState.language),
                value: ride.destinationLabel
            )

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(formatIqd(ride.fareAmountIqd))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(BrandColors.tealDark)
                Text(L10n.string(.paymentMethodCash, language: appState.language))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(BrandColors.muted)
            }
        }
        .appCard()
    }

    private func summaryRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(iconColor, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BrandColors.muted)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var ratingSection: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(L10n.string(.rateYourDriver, language: appState.language))
                .font(.headline)
                .foregroundStyle(BrandColors.navy)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: AppSpacing.sm) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedRating = star
                        }
                    } label: {
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(BrandColors.gold)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)

            TextField(L10n.string(.feedbackOptional, language: appState.language), text: $feedback, axis: .vertical)
                .textFieldStyle(AppTextFieldStyle())
                .lineLimit(3...6)

            Button(L10n.string(.submitRating, language: appState.language)) {
                Task { await submitRating() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedRating < 1 || isSubmitting)
        }
        .appCard()
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
