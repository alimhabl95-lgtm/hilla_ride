import SwiftUI

/// Customer home with Ride + Stores tabs (marketplace is fully live/synced).
struct CustomerHomeShellView: View {
    @EnvironmentObject private var appState: AppState
    let user: AppUser
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if selectedTab == 0 {
                    CustomerHomeMapView(user: user)
                } else {
                    MarketplaceHomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(
                index: 0,
                title: appState.language == .arabic ? "رحلة" : "Ride",
                systemImage: "car.fill"
            )
            tabButton(
                index: 1,
                title: appState.language == .arabic ? "متاجر" : "Stores",
                systemImage: "storefront.fill"
            )
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .background {
            Rectangle()
                .fill(.white)
                .shadow(color: BrandColors.navy.opacity(0.08), radius: 12, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BrandColors.border)
                .frame(height: 1)
        }
    }

    private func tabButton(index: Int, title: String, systemImage: String) -> some View {
        let isSelected = selectedTab == index

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(BrandColors.teal.opacity(0.12))
                            .frame(width: 56, height: 32)
                    }
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? BrandColors.tealDark : BrandColors.muted)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
    }
}
