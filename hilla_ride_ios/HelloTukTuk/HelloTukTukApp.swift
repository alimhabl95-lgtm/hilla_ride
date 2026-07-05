import SwiftUI

@main
struct HelloTukTukApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    init() {
        FirebaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .tint(BrandColors.teal)
        }
    }
}
