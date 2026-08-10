import SwiftUI

struct CustomerRewardsView: View {
    @EnvironmentObject private var appState: AppState
    let user: AppUser

    var body: some View {
        let isAr = appState.language == .arabic
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isAr ? "المكافآت والعروض" : "Rewards & offers")
                        .font(.headline.weight(.bold))
                    if user.hasPromoRemaining {
                        Text(
                            L10n.customerPromoBanner(
                                code: user.promoCode,
                                remaining: max(0, user.promoRidesLimit - user.promoRidesUsed),
                                language: appState.language
                            )
                        )
                        .foregroundStyle(BrandColors.tealDark)
                    } else if !user.promoCode.isEmpty {
                        Text(
                            isAr
                                ? "تم استخدام عرض \(user.promoCode)."
                                : "Promo \(user.promoCode) has been used."
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Text(
                            isAr
                                ? "لا توجد مكافآت نشطة حالياً. راقب الإعلانات للعروض الجديدة."
                                : "No active rewards right now. Check announcements for new offers."
                        )
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()

                Text(
                    isAr
                        ? "احفظ الأماكن المفضلة واطلب رحلات أكثر لفتح عروض مستقبلية."
                        : "Save favorite places and take more trips to unlock future offers."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.xxl)
        }
        .background(BrandColors.surface.ignoresSafeArea())
        .navigationTitle(isAr ? "المكافآت" : "Rewards")
        .navigationBarTitleDisplayMode(.inline)
    }
}
