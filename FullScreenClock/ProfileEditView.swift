
import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) var dismiss
    var profile: BabyProfile

    @State private var name: String = ""

    var body: some View {
        NavigationView {
            Form {
                TextField(String(localized: "Baby's Name"), text: $name)
            }
            .navigationTitle(String(localized: "Edit Profile"))
            .onAppear {
                name = profile.name
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save() }
                }
            }
        }
    }

    private func save() {
        viewModel.updateProfile(profile: profile, newName: name)
        dismiss()
    }
}
