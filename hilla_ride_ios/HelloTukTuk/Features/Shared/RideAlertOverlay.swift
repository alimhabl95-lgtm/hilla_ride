import SwiftUI
import UIKit

struct RideAlertOverlay<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var alertService = RideAlertService.shared
    @ViewBuilder let content: () -> Content

    @State private var showDialog = false
    @State private var isActing = false
    @State private var actionError: String?

    var body: some View {
        ZStack(alignment: .top) {
            content()

            if let alert = alertService.activeAlert {
                alertBanner(alert)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: alertService.activeAlert?.id)
        .onChange(of: alertService.activeAlert?.id) { _ in
            if alertService.activeAlert != nil {
                showDialog = true
                actionError = nil
            }
        }
        .alert(
            alertService.activeAlert?.title ?? "",
            isPresented: $showDialog,
            presenting: alertService.activeAlert
        ) { alert in
            if alert.type == .driverRideRequest, let rideId = alert.rideId, !rideId.isEmpty {
                Button(L10n.string(.rejectRide, language: appState.language), role: .destructive) {
                    Task { await rejectOffer(rideId: rideId) }
                }
                Button(L10n.string(.acceptRide, language: appState.language)) {
                    Task { await acceptOffer(rideId: rideId) }
                }
                .disabled(isActing)
            } else {
                Button(L10n.string(.done, language: appState.language)) {
                    alertService.dismissAlert()
                }
            }
        } message: { alert in
            Text(alert.body)
        }
        .alert(
            appState.language == .arabic ? "تعذر إكمال الطلب" : "Could not complete",
            isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )
        ) {
            Button(L10n.string(.done, language: appState.language)) {
                actionError = nil
            }
        } message: {
            Text(actionError ?? "")
        }
    }

    private func alertBanner(_ alert: RideAlertEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Button {
                    alertService.dismissAlert()
                    showDialog = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                }
            }

            if alert.type == .driverRideRequest, let rideId = alert.rideId, !rideId.isEmpty {
                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await rejectOffer(rideId: rideId) }
                    } label: {
                        Group {
                            if isActing {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            } else {
                                Text(L10n.string(.rejectRide, language: appState.language))
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.18), in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .disabled(isActing)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await acceptOffer(rideId: rideId) }
                    } label: {
                        Group {
                            if isActing {
                                ProgressView()
                                    .tint(BrandColors.tealDark)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            } else {
                                Text(L10n.string(.acceptRide, language: appState.language))
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.white, in: Capsule())
                                    .foregroundStyle(BrandColors.tealDark)
                            }
                        }
                    }
                    .disabled(isActing)
                }
            }
        }
        .padding(16)
        .background(bannerColor(for: alert.type))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 8)
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

    private func acceptOffer(rideId: String) async {
        guard let driverId = appState.currentUser?.uid else { return }
        await MainActor.run { isActing = true }
        defer { Task { @MainActor in isActing = false } }
        do {
            try await RideRepository().acceptRide(rideId: rideId, driverId: driverId)
            await MainActor.run {
                showDialog = false
                alertService.dismissAlert()
            }
        } catch {
            await MainActor.run {
                actionError = error.localizedDescription
            }
        }
    }

    private func rejectOffer(rideId: String) async {
        guard let driverId = appState.currentUser?.uid else { return }
        await MainActor.run { isActing = true }
        defer { Task { @MainActor in isActing = false } }
        do {
            try await RideRepository().rejectRide(rideId: rideId, driverId: driverId)
            await MainActor.run {
                showDialog = false
                alertService.dismissAlert()
            }
        } catch {
            await MainActor.run {
                actionError = error.localizedDescription
            }
        }
    }
}
