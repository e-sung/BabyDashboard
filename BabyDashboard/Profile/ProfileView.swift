import SwiftUI
import CoreData
import Model

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ProfileViewModel

    @State private var name: String = ""
    @State private var showingDeleteConfirm = false
    #if DEBUG
    @State private var feedTerm: TimeInterval = 180
    #else
    @State private var feedTerm: TimeInterval = 180 * 60
    #endif
    @State private var showingShareSheet = false
    @State private var shareError: String?

    private var canDeleteProfile: Bool {
        viewModel.canDeleteProfile
    }

    // Reusable localized formatter for hours/minutes
    private static let intervalFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .short
        f.zeroFormattingBehavior = [.dropAll]
        return f
    }()

    init(profile: BabyProfile, context: NSManagedObjectContext, shareController: ShareController) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(profile: profile, context: context, shareController: shareController))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(String(localized: "Profile")) {
                    TextField(String(localized: "Baby's Name"), text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section(String(localized: "Feeding Interval")) {
                    Stepper(
                        value: $feedTerm,
                        in: range,
                        step: step,
                    ) {
                        Text(formattedInterval(seconds: feedTerm))
                    }
                    .accessibilityLabel(Text("Feeding Interval"))
                    .accessibilityValue(Text(formattedInterval(seconds: feedTerm)))
                    Text("Choose how long between feeds to use for progress and warnings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                sharingSection

                if canDeleteProfile {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Text(String(localized: "Delete Baby"))
                        }
                    }
                } else {
                    Section {
                        Text("You are a participant in this shared baby. You can log feeds and diapers, but profile settings are managed by the owner.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                name = viewModel.profile.name
                let v = viewModel.profile.feedTerm
                feedTerm = min(max(v, range.lowerBound), range.upperBound)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save() }
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
            .sheet(isPresented: $showingShareSheet) {
                BabyShareSheet(baby: viewModel.profile) {
                    viewModel.refreshShareInfo()
                } onError: { error in
                    shareError = error.localizedDescription
                }
            }
            .alert("Sharing Error", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
                Button("OK", role: .cancel) { shareError = nil }
            } message: {
                Text(shareError ?? "")
            }
        }
    }

    private var sharingSection: some View {
        Section(String(localized: "Sharing")) {
            HStack {
                Label(shareStatusDescription, systemImage: shareStatusIcon)
                Spacer()
                if viewModel.shareInfo.participantCount > 0 {
                    let countText = String(
                        format: NSLocalizedString("Shared with %d", comment: "Share participant count"),
                        viewModel.shareInfo.participantCount
                    )
                    Text(countText)
                        .foregroundStyle(.secondary)
                }
            }

            Button(shareButtonTitle) {
                showingShareSheet = true
            }
            .accessibilityHint(Text("Opens CloudKit sharing controls"))
        }
    }

    private var shareStatusDescription: String {
        switch viewModel.shareInfo.role {
        case .owner:
            return String(localized: "You are the owner")
        case .participant:
            return String(localized: "You are a participant")
        case .notShared:
            return String(localized: "Not shared")
        case .unknown:
            return String(localized: "Share status pending")
        }
    }

    private var shareStatusIcon: String {
        switch viewModel.shareInfo.role {
        case .owner: return "person.crop.circle.badge.checkmark"
        case .participant: return "person.2.fill"
        case .notShared: return "person.fill"
        case .unknown: return "ellipsis.circle"
        }
    }

    private var shareButtonTitle: String {
        switch viewModel.shareInfo.role {
        case .notShared:
            return String(localized: "Share Baby")
        case .owner, .participant, .unknown:
            return String(localized: "Manage Share")
        }
    }

    private var step: TimeInterval {
        #if DEBUG
        return 10
        #else
        return 15 * 60
        #endif
    }

    private var range: ClosedRange<TimeInterval> {
        #if DEBUG
        return 10...180
        #else
        return 1800...28800
        #endif
    }

    private func formattedInterval(seconds: TimeInterval) -> String {
        if let s = Self.intervalFormatter.string(from: seconds) {
            return s
        }
        return String(localized: "\(Int(seconds / 60)) min")
    }

    private func save() {
        viewModel.saveProfile(name: name, feedTerm: feedTerm)
        dismiss()
    }

    private func deleteProfile() {
        guard canDeleteProfile else { return }
        viewModel.deleteProfile()
        dismiss()
    }
}
