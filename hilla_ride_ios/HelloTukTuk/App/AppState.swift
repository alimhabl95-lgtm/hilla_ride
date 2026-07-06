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

    var needsProfileRecovery: Bool {
        Auth.auth().currentUser != nil && currentUser == nil && !isBootstrapping
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
        await refreshCurrentUser(firebaseUser: Auth.auth().currentUser)
        await PushNotificationService.shared.requestAuthorizationIfNeeded()
        isBootstrapping = false
    }

    func selectMode(_ mode: UserRole) {
        selectedMode = mode
    }

    func setCurrentUser(_ user: AppUser) {
        currentUser = user
        Task {
            await refreshDriverProfileIfNeeded()
            await PushNotificationService.shared.saveToken(for: user.uid, role: user.role)
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
            await PushNotificationService.shared.saveToken(for: user.uid, role: user.role)
        } catch {
            currentUser = nil
            currentDriver = nil
        }
    }
}
