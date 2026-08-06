import SwiftUI

struct AnnouncementBannerView: View {
    let audience: String

    @State private var announcements: [Announcement] = []
    @State private var dismissedIds: Set<String> = []
    @State private var watchTask: Task<Void, Never>?

    private let service = AnnouncementService()

    private var activeBanner: Announcement? {
        announcements.first { item in
            !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !dismissedIds.contains(item.id)
        }
    }

    var body: some View {
        Group {
            if let banner = activeBanner {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "megaphone.fill")
                        .foregroundStyle(BrandColors.tealDark)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(banner.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BrandColors.navy)
                        if !banner.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(banner.body)
                                .font(.caption)
                                .foregroundStyle(BrandColors.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        service.dismissBanner(id: banner.id, audience: audience)
                        dismissedIds.insert(banner.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BrandColors.muted)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(BrandColors.teal.opacity(0.12))
            }
        }
        .onAppear {
            dismissedIds = service.getDismissedBannerIds(audience: audience)
            watchTask?.cancel()
            watchTask = Task {
                for await batch in service.watchActiveBanners(audience: audience) {
                    guard !Task.isCancelled else { return }
                    announcements = batch
                }
            }
        }
        .onDisappear {
            watchTask?.cancel()
            watchTask = nil
        }
    }
}
