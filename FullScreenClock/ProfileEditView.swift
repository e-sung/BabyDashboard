
import SwiftUI

struct ProfileEditView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) var dismiss
    var profile: BabyProfile?

    @State private var name: String = ""

    var body: some View {
        NavigationView {
            Form {
                TextField("Baby's Name", text: $name)
            }
            .navigationTitle(profile == nil ? "Add Profile" : "Edit Profile")
            .onAppear {
                if let profile = profile {
                    name = profile.name
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        if let profile = profile {
            viewModel.updateProfile(profile: profile, newName: name)
        } else {
            viewModel.addProfile(name: name)
        }
        dismiss()
    }
}
