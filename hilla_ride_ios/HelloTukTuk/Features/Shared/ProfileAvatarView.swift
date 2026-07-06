import SwiftUI

struct ProfileAvatarView: View {
    let name: String
    let photoURL: String?
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let photoURL, let url = URL(string: photoURL), !photoURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsView: some View {
        Circle()
            .fill(BrandColors.teal.opacity(0.2))
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(BrandColors.tealDark)
            }
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        if parts.isEmpty { return "?" }
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }
}
