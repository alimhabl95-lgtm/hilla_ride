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
    @State private var promo: PromoApplication?
    @State private var isLoadingQuote = true
    @State private var isBooking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppSheetHandle()
                    .padding(.top, AppSpacing.sm)

                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text(L10n.string(.bookRideTitle, language: appState.language))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(BrandColors.navy)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    routeSummaryCard

                    fareCard

                    if let errorMessage {
                        AppBanner(message: errorMessage, systemImage: "exclamationmark.triangle.fill", tone: .danger)
                    }

                    Button(L10n.string(.confirmBooking, language: appState.language)) {
                        Task { await bookRide() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoadingQuote || isBooking || quote?.canBook != true)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
            }
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

    private var routeSummaryCard: some View {
        VStack(spacing: AppSpacing.md) {
            routePoint(
                icon: "circle.fill",
                iconColor: BrandColors.success,
                title: L10n.string(.pickupLabel, language: appState.language),
                value: pickup.label
            )

            HStack {
                Rectangle()
                    .fill(BrandColors.border)
                    .frame(width: 2, height: 20)
                    .padding(.leading, 13)
                Spacer()
            }

            routePoint(
                icon: "mappin.circle.fill",
                iconColor: BrandColors.danger,
                title: L10n.string(.destinationLabel, language: appState.language),
                value: destination.label
            )
        }
        .appCard()
    }

    private func routePoint(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(iconColor, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BrandColors.muted)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BrandColors.navy)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var fareCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if isLoadingQuote {
                HStack(spacing: AppSpacing.md) {
                    ProgressView()
                    Text(L10n.string(.loading, language: appState.language))
                        .font(.subheadline)
                        .foregroundStyle(BrandColors.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let quote {
                if quote.outOfService {
                    AppBanner(
                        message: L10n.string(.outOfService, language: appState.language),
                        systemImage: "xmark.octagon.fill",
                        tone: .danger
                    )
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.string(.distance, language: appState.language))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(BrandColors.muted)
                            Text(String(format: "%.1f km", quote.distanceKm))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandColors.navy)
                        }
                        Spacer()
                    }

                    Divider()

                    if let promo, promo.hasDiscount, let baseFare = quote.fareIqd {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Text(L10n.string(.estimatedFare, language: appState.language))
                                    .font(.caption)
                                    .foregroundStyle(BrandColors.muted)
                                Spacer()
                                Text(formatIqd(baseFare))
                                    .font(.subheadline)
                                    .strikethrough()
                                    .foregroundStyle(BrandColors.muted)
                            }

                            AppBanner(
                                message: L10n.promoDiscountApplied(
                                    code: promo.promoCode,
                                    amount: formatIqd(promo.discountIqd),
                                    language: appState.language
                                ),
                                systemImage: "tag.fill",
                                tone: .warning
                            )

                            Text(L10n.string(.finalFare, language: appState.language))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(BrandColors.muted)
                            Text(formatIqd(promo.finalFareIqd))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(BrandColors.tealDark)
                        }
                    } else {
                        Text(L10n.string(.estimatedFare, language: appState.language))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BrandColors.muted)
                        Text(formatIqd(quote.fareIqd ?? 0))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(BrandColors.tealDark)
                    }
                }
            }
        }
        .appCard()
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
        let rideQuote = await pricing.quoteRide(
            pickup: pickup.coordinate,
            destination: destination.coordinate,
            districtId: districtId,
            subDistrictId: subDistrictId
        )
        quote = rideQuote

        if let baseFare = rideQuote.fareIqd, user.hasLoyaltyFreeRide {
            promo = PromoApplication(
                baseFareIqd: baseFare,
                discountIqd: baseFare,
                finalFareIqd: 0,
                promoCode: "LOYALTY"
            )
        } else if let baseFare = rideQuote.fareIqd, user.hasPromoRemaining {
            let config = await PromoService().getPromoCode(user.promoCode)
            promo = PromoService().applyPromo(user: user, config: config, baseFareIqd: baseFare)
        } else {
            promo = nil
        }
    }

    private func bookRide() async {
        guard let quote, let baseFare = quote.fareIqd else { return }
        let isLoyalty = promo?.promoCode == "LOYALTY"
        let finalFare = promo?.hasDiscount == true ? promo!.finalFareIqd : baseFare
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
                fareAmountIqd: finalFare,
                distanceKm: quote.distanceKm,
                originalFareIqd: promo?.hasDiscount == true ? baseFare : 0,
                promoDiscountIqd: promo?.discountIqd ?? 0,
                promoCode: promo?.promoCode ?? "",
                loyaltyFreeRide: isLoyalty
            )
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
