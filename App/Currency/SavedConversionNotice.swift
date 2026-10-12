import SwiftUI

struct SavedConversionNotice: View {
    @ObservedObject var saved: SavedConversions
    let openSaved: () -> Void
    var body: some View {
        if saved.lastSavedID != nil {
            VStack(alignment: .leading, spacing: 6) {
                Label("Saved on this device", systemImage: "checkmark.circle.fill").font(.subheadline)
                HStack {
                    Button("View saved entries", action: openSaved).frame(minHeight: 44)
                    Spacer()
                    Button { saved.clearSaveNotice() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("Dismiss saved confirmation")
                }
            }.padding(10).background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
