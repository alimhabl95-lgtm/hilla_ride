import SwiftUI

struct RideAlertOverlay<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var alertService = RideAlertService.shared
    @ViewBuilder let content: () -> Content

    @State private var showDialog = false

    var body: some View {
        ZStack(alignment: .top) {
            content()

            if let alert = alertService.activeAlert {
                alertBanner(alert)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: alertService.activeAlert?.id)
        .onChange(of: alertService.activeAlert?.id) { _, _ in
            if alertService.activeAlert != nil {
                showDialog = true
            }
        }
        .alert(
            alertService.activeAlert?.title ?? "",
            isPresented: $showDialog,
            presenting: alertService.activeAlert
        ) { _ in
            Button(L10n.string(.done, language: appState.language)) {
                alertService.dismissAlert()
            }
        } message: { alert in
            Text(alert.body)
        }
    }

    private func alertBanner(_ alert: RideAlertEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: alert.type))
                .font(.title2)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(alert.body)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
            }
            Spacer()
            Button {
                alertService.dismissAlert()
                showDialog = false
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(bannerColor(for: alert.type))
    }

    private func bannerColor(for type: RideAlertType) -> Color {
        switch type {
        case .driverRideRequest: return BrandColors.tealDark
        case .customerRideAccepted: return Color(red: 0.01, green: 0.41, blue: 0.64)
        case .chatMessage: return Color(red: 0.49, green: 0.23, blue: 0.93)
        }
    }

    private func iconName(for type: RideAlertType) -> String {
        switch type {
        case .driverRideRequest: return "bell.fill"
        case .customerRideAccepted: return "checkmark.circle.fill"
        case .chatMessage: return "message.fill"
        }
    }
}
