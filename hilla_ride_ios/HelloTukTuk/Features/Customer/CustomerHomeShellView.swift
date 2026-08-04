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
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(.ultraThinMaterial)
        }
    }

    private func tabButton(index: Int, title: String, systemImage: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedTab == index ? BrandColors.tealDark : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
