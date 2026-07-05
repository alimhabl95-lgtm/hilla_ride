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
    @Published private(set) var isBootstrapping = true

    let authService = AuthService()
    private var authListener: AuthStateDidChangeListenerHandle?

    init() {
        let savedLanguage = UserDefaults.standard.string(forKey: "app_language")
        language = AppLanguage(rawValue: savedLanguage ?? "ar") ?? .arabic

        if let savedMode = UserDefaults.standard.string(forKey: "selected_mode"),
           let mode = UserRole(rawValue: savedMode) {
            selectedMode = mode
        }

        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { await self?.refreshCurrentUser(firebaseUser: user) }
        }
    }

    deinit {
        if let authListener {
            Auth.auth().removeStateDidChangeListener(authListener)
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
            await PushNotificationService.shared.saveToken(for: user.uid, role: user.role)
        }
    }

    func signOut() async throws {
        try await authService.signOut()
        currentUser = nil
    }

    private func refreshCurrentUser(firebaseUser: User?) async {
        guard let firebaseUser else {
            currentUser = nil
            return
        }

        do {
            let repository = UserRepository()
            currentUser = try await repository.fetchUser(uid: firebaseUser.uid)
            if let currentUser {
                await PushNotificationService.shared.saveToken(for: currentUser.uid, role: currentUser.role)
            }
        } catch {
            currentUser = nil
        }
    }
}
