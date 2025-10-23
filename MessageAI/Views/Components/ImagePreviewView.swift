import SwiftUI

struct ImagePreviewView: View {
    @Binding var image: UIImage?
    @Binding var caption: String
    var onSend: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                TextField("Add a caption...", text: $caption, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .padding()
            }
            .navigationTitle("Send Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        onSend()
                    }
                    .bold()
                }
            }
        }
    }
}

#Preview {
    ImagePreviewView(
        image: .constant(UIImage(systemName: "photo")),
        caption: .constant(""),
        onSend: {},
        onCancel: {}
    )
}
