
import SwiftUI

struct ProfileManagementView: View {
    @ObservedObject var viewModel: ContentViewModel
    @State private var isAddingProfile = false
    @State private var editingProfile: BabyProfile? = nil

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.profiles) { profile in
                    HStack {
                        Text(profile.name)
                        Spacer()
                        Button("Edit") {
                            editingProfile = profile
                        }
                    }
                }
                .onDelete(perform: deleteProfile)
                .onMove(perform: moveProfile)
            }
            .navigationTitle("Manage Profiles")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isAddingProfile = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingProfile) {
                ProfileEditView(viewModel: viewModel)
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditView(viewModel: viewModel, profile: profile)
            }
        }
    }

    private func deleteProfile(at offsets: IndexSet) {
        viewModel.deleteProfile(at: offsets)
    }

    private func moveProfile(from source: IndexSet, to destination: Int) {
        viewModel.moveProfile(from: source, to: destination)
    }
}

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
