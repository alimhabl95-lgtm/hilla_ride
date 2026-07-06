import SwiftUI

struct AnnouncementsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var announcements: [Announcement] = []
    @State private var readIds = Set<String>()
    @State private var task: Task<Void, Never>?

    private var audience: String {
        appState.currentUser?.role == .driver ? "drivers" : "customers"
    }

    var body: some View {
        List(announcements) { item in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    if !readIds.contains(item.id) {
                        Circle()
                            .fill(BrandColors.gold)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .onAppear {
                AnnouncementService().markRead(item.id)
                readIds.insert(item.id)
            }
        }
        .overlay {
            if announcements.isEmpty {
                Text(L10n.string(.announcementsEmpty, language: appState.language))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.string(.announcementsTitle, language: appState.language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            readIds = AnnouncementService().getReadIds()
            startWatching()
        }
        .onDisappear { task?.cancel() }
    }

    private func startWatching() {
        task = Task {
            for await batch in AnnouncementService().watchAnnouncements(audience: audience) {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    announcements = batch
                    AnnouncementService().markAllRead(batch.map(\.id))
                    readIds = AnnouncementService().getReadIds()
                }
            }
        }
    }
}

struct AnnouncementIconButton: View {
    @EnvironmentObject private var appState: AppState
    @Binding var showAnnouncements: Bool

    @State private var unreadCount = 0
    @State private var task: Task<Void, Never>?

    private var audience: String {
        appState.currentUser?.role == .driver ? "drivers" : "customers"
    }

    var body: some View {
        Button {
            showAnnouncements = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "megaphone")
                if unreadCount > 0 {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .onAppear { startWatching() }
        .onDisappear { task?.cancel() }
    }

    private func startWatching() {
        let service = AnnouncementService()
        task = Task {
            for await batch in service.watchAnnouncements(audience: audience) {
                guard !Task.isCancelled else { break }
                let read = service.getReadIds()
                await MainActor.run {
                    unreadCount = service.unreadCount(announcements: batch, readIds: read)
                }
            }
        }
    }
}

struct LegalDocumentsMenu: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Menu {
            Link(L10n.string(.privacyPolicy, language: appState.language),
                 destination: LegalConfig.privacyPolicyURL(languageCode: appState.language.rawValue))
            Link(L10n.string(.termsOfService, language: appState.language),
                 destination: LegalConfig.termsOfServiceURL(languageCode: appState.language.rawValue))
        } label: {
            Image(systemName: "doc.text")
        }
    }
}

struct CurrentRideIconButton: View {
    @EnvironmentObject private var appState: AppState
    let role: UserRole

    @State private var hasActiveRide = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .navigateToCurrentRide, object: nil)
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "car.fill")
                    .foregroundStyle(hasActiveRide ? BrandColors.teal : .secondary)
                if hasActiveRide {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .disabled(!hasActiveRide)
        .onAppear { startWatching() }
        .onDisappear { task?.cancel() }
    }

    private func startWatching() {
        guard let uid = appState.currentUser?.uid else { return }
        task = Task {
            let stream: AsyncStream<Ride?>
            if role == .driver {
                stream = RideRepository().watchAssignedRide(for: uid)
            } else {
                stream = RideRepository().watchActiveRide(customerId: uid)
            }
            for await ride in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    hasActiveRide = ride != nil
                }
            }
        }
    }
}

extension Notification.Name {
    static let navigateToCurrentRide = Notification.Name("navigateToCurrentRide")
}
