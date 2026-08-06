import FirebaseFirestore
import Foundation

final class AnnouncementService {
    private let firestore = Firestore.firestore()
    private let readIdsKey = "read_announcement_ids"

    private func dismissedBannerKey(audience: String) -> String {
        "dismissed_banner_ids_\(audience)"
    }

    func watchAnnouncements(audience: String) -> AsyncStream<[Announcement]> {
        AsyncStream { continuation in
            let listener = firestore.collection("announcements")
                .whereField("audience", isEqualTo: audience)
                .limit(to: 40)
                .addSnapshotListener { snapshot, _ in
                    let items = snapshot?.documents.compactMap { doc in
                        Announcement(documentID: doc.documentID, data: doc.data())
                    } ?? []
                    let sorted = items.sorted {
                        ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                    }
                    continuation.yield(sorted)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func watchActiveBanners(audience: String) -> AsyncStream<[Announcement]> {
        AsyncStream { continuation in
            let listener = firestore.collection("announcements")
                .whereField("audience", isEqualTo: audience)
                .limit(to: 20)
                .addSnapshotListener { snapshot, _ in
                    let items = snapshot?.documents.compactMap { doc in
                        Announcement(documentID: doc.documentID, data: doc.data())
                    } ?? []
                    let sorted = items.sorted {
                        ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                    }
                    let bannerItems = Array(sorted.filter(\.showAsBanner).prefix(5))
                    continuation.yield(bannerItems.isEmpty ? Array(sorted.prefix(5)) : bannerItems)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func getDismissedBannerIds(audience: String) -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: dismissedBannerKey(audience: audience)) ?? [])
    }

    func dismissBanner(id: String, audience: String) {
        var dismissed = getDismissedBannerIds(audience: audience)
        guard !dismissed.contains(id) else { return }
        dismissed.insert(id)
        UserDefaults.standard.set(Array(dismissed), forKey: dismissedBannerKey(audience: audience))
    }

    func getReadIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: readIdsKey) ?? [])
    }

    func markRead(_ id: String) {
        var read = getReadIds()
        guard !read.contains(id) else { return }
        read.insert(id)
        UserDefaults.standard.set(Array(read), forKey: readIdsKey)
    }

    func markAllRead(_ ids: [String]) {
        var read = getReadIds()
        ids.forEach { read.insert($0) }
        UserDefaults.standard.set(Array(read), forKey: readIdsKey)
    }

    func unreadCount(announcements: [Announcement], readIds: Set<String>) -> Int {
        announcements.filter { !readIds.contains($0.id) }.count
    }
}
