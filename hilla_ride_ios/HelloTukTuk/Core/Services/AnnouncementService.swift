import FirebaseFirestore
import Foundation

final class AnnouncementService {
    private let firestore = Firestore.firestore()
    private let readIdsKey = "read_announcement_ids"

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
