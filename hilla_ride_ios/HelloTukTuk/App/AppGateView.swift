import SwiftUI

struct AppGateView<Content: View>: View {
    @EnvironmentObject private var appState: AppState
    @ViewBuilder let content: () -> Content

    @State private var remoteConfig = AppRemoteConfig.defaults
    @State private var configTask: Task<Void, Never>?
    @State private var showForceUpdate = false

    private var currentBuildNumber: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "") ?? 0
    }

    private var needsForceUpdate: Bool {
        remoteConfig.minIosBuild > 0 && currentBuildNumber < remoteConfig.minIosBuild
    }

    private var isAdminBypass: Bool {
        guard let user = appState.currentUser else { return false }
        return user.role == .manager || user.role == .assistant
    }

    var body: some View {
        Group {
            if remoteConfig.maintenanceMode && !isAdminBypass {
                maintenanceScreen
            } else if needsForceUpdate {
                forceUpdateScreen
            } else {
                content()
            }
        }
        .onAppear { startWatchingConfig() }
        .onDisappear {
            configTask?.cancel()
            configTask = nil
        }
        .alert(
            appState.language == .arabic ? "تحديث مطلوب" : "Update required",
            isPresented: $showForceUpdate
        ) {
            if let url = URL(string: remoteConfig.iosStoreUrl), !remoteConfig.iosStoreUrl.isEmpty {
                Link(
                    appState.language == .arabic ? "تحديث الآن" : "Update now",
                    destination: url
                )
            }
        } message: {
            Text(forceUpdateMessage)
        }
    }

    private var maintenanceScreen: some View {
        VStack(spacing: 24) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 72))
                .foregroundStyle(BrandColors.teal)
            Text(maintenanceMessage)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
    }

    private var forceUpdateScreen: some View {
        VStack(spacing: 24) {
            ProgressView()
            Text(forceUpdateMessage)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let url = URL(string: remoteConfig.iosStoreUrl), !remoteConfig.iosStoreUrl.isEmpty {
                Link(
                    appState.language == .arabic ? "تحديث الآن" : "Update now",
                    destination: url
                )
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColors.surface.ignoresSafeArea())
        .onAppear { showForceUpdate = true }
    }

    private var maintenanceMessage: String {
        let message = remoteConfig.maintenanceMessage(language: appState.language)
        if message.isEmpty {
            return appState.language == .arabic
                ? "التطبيق تحت الصيانة. يرجى المحاولة لاحقاً."
                : "The app is under maintenance. Please try again later."
        }
        return message
    }

    private var forceUpdateMessage: String {
        let message = remoteConfig.forceUpdateMessage(language: appState.language)
        if message.isEmpty {
            return appState.language == .arabic
                ? "يرجى تحديث التطبيق للمتابعة."
                : "Please update the app to continue."
        }
        return message
    }

    private func startWatchingConfig() {
        configTask?.cancel()
        configTask = Task {
            for await config in AppConfigService.shared.watchConfig() {
                guard !Task.isCancelled else { break }
                await MainActor.run { remoteConfig = config }
            }
        }
    }
}
