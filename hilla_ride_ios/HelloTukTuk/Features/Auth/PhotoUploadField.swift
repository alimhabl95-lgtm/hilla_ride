import PhotosUI
import SwiftUI
import UIKit

struct PhotoUploadField: View {
    @EnvironmentObject private var appState: AppState
    let title: String
    @Binding var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())

            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .frame(height: 140)

                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(BrandColors.teal)
                            Text(L10n.string(.tapToUploadPhoto, language: appState.language))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
              .onChange(of: selectedItem) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            imageData = data
                        }
                    }
                }
            }
        }
    }
}
