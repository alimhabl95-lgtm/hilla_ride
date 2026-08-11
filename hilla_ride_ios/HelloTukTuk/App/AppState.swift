import FirebaseAuth
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "app_language") }
    }
    @Published var selectedMode: UserRole? {
        didSet {
            if let selectedMode {
                UserDefaults.standard.set(selectedMode.rawValue, forKey: "selected_mode")
            }
        }
    }
    @Published private(set) var currentUser: AppUser?
    @Published private(set) var currentDriver: DriverProfile?
    @Published private(set) var isBootstrapping = true
    @Published private(set) var isPerformingSignup = false

    var needsProfileRecovery: Bool {
        Auth.auth().currentUser != nil && currentUser == nil && !isBootstrapping && !isPerformingSignup
    }

    func beginSignupFlow() {
        isPerformingSignup = true
    }

    func endSignupFlow() {
        isPerformingSignup = false
    }

    let authService = AuthService()
    private let driverRepository = DriverRepository()
    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "app_language")
        language = AppLanguage(rawValue: savedLanguage ?? "ar") ?? .arabic

        if let savedMode = UserDefaults.standard.string(forKey: "selected_mode"),
           let mode = UserRole(rawValue: savedMode) {
            selectedMode = mode
        }

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                await self?.refreshCurrentUser(firebaseUser: user)
            }
        }
    }

    func finishBootstrap() async {
        ServiceAreaCatalog.shared.start()
        await refreshCurrentUser(firebaseUser: Auth.auth().currentUser)
        isBootstrapping = false
        schedulePushSetup()
    }

    /// Push permission + FCM token must not block the first screen — Messaging.token()
    /// can wait indefinitely for APNs during cold start.
    private func schedulePushSetup() {
        Task {
            await PushNotificationService.shared.requestAuthorizationIfNeeded()
            if let user = currentUser {
                await PushNotificationService.shared.saveToken(for: user.uid, role: user.role)
            }
        }
    }

    private func schedulePushTokenSave(for user: AppUser) {
        Task {
            await PushNotificationService.shared.saveToken(for: user.uid, role: user.role)
        }
    }

    func selectMode(_ mode: UserRole) {
        selectedMode = mode
    }

    func setCurrentUser(_ user: AppUser) {
        currentUser = user
        Task {
            await refreshDriverProfileIfNeeded()
            schedulePushTokenSave(for: user)
        }
    }

    func signOut() async throws {
        try await authService.signOut()
        currentUser = nil
        currentDriver = nil
    }

    func refreshDriverProfileIfNeeded() async {
        guard let user = currentUser, user.role == .driver else {
            currentDriver = nil
            return
        }
        currentDriver = try? await driverRepository.fetchDriver(uid: user.uid)
    }

    private func refreshCurrentUser(firebaseUser: User?) async {
        if isPerformingSignup {
            return
        }

        guard let firebaseUser else {
            currentUser = nil
            currentDriver = nil
            return
        }

        do {
            let repository = UserRepository()
            guard let user = try await repository.fetchUser(uid: firebaseUser.uid) else {
                currentUser = nil
                currentDriver = nil
                return
            }
            currentUser = user
            await refreshDriverProfileIfNeeded()
            schedulePushTokenSave(for: user)
        } catch {
            currentUser = nil
            currentDriver = nil
        }
    }
}
