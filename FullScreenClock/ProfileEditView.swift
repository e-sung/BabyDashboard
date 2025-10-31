import SwiftUI
import SwiftData
import Model

struct ProfileEditView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    var profile: BabyProfile

    @State private var name: String = ""
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationView {
            Form {
                Section(String(localized: "Profile")) {
                    TextField(String(localized: "Baby's Name"), text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text(String(localized: "Delete Baby"))
                    }
                }
            }
            .navigationTitle(String(localized: "Edit Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                name = profile.name
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert(
                String(localized: "Delete Baby?"),
                isPresented: $showingDeleteConfirm
            ) {
                Button(String(localized: "Delete"), role: .destructive) {
                    deleteProfile()
                }
                Button(String(localized: "Cancel"), role: .cancel) { }
            } message: {
                Text(String(localized: "This will remove the baby profile. History (feeds and diapers) will be kept but no longer associated with this baby."))
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.updateProfileName(for: profile, to: trimmed)
        // updateProfileName already saves and pings
        dismiss()
    }

    private func deleteProfile() {
        modelContext.delete(profile)
        try? modelContext.save()
        NearbySyncManager.shared.sendPing()
        dismiss()
    }
}
