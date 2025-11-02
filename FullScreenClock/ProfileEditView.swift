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

    // New: editable feeding interval in minutes (backed by profile.feedTerm seconds)
    @State private var feedTermMinutes: Int = 180

    // Reusable localized formatter for hours/minutes
    private static let intervalFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .short
        f.zeroFormattingBehavior = [.dropAll]
        return f
    }()

    var body: some View {
        NavigationView {
            Form {
                Section(String(localized: "Profile")) {
                    TextField(String(localized: "Baby's Name"), text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section(String(localized: "Feeding Interval")) {
                    Stepper(
                        value: $feedTermMinutes,
                        in: 30...480,
                        step: 15
                    ) {
                        Text(formattedInterval(minutes: feedTermMinutes))
                    }
                    .accessibilityLabel(Text("Feeding Interval"))
                    .accessibilityValue(Text(formattedInterval(minutes: feedTermMinutes)))
                    Text("Choose how long between feeds to use for progress and warnings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                feedTermMinutes = max(1, Int(profile.feedTerm / 60)) // default to current value; guard minimum
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

    private func formattedInterval(minutes: Int) -> String {
        let seconds = TimeInterval(minutes * 60)
        if let s = Self.intervalFormatter.string(from: seconds) {
            return s
        }
        // Fallback (rare)
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return String(localized: "\(hours) hr")
        } else {
            return String(localized: "\(hours) hr \(mins) min")
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Update feed term first so the save in updateProfileName persists both changes.
        profile.feedTerm = TimeInterval(feedTermMinutes * 60)

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
