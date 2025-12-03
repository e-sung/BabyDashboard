import SwiftUI
import CoreData
import Model

struct CustomEventTypeManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let baby: BabyProfile
    
    @FetchRequest private var eventTypes: FetchedResults<CustomEventType>
    
    @State private var isShowingAddSheet = false
    @State private var eventTypeToEdit: CustomEventType?
    @State private var eventTypeToDelete: CustomEventType?
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    
    init(baby: BabyProfile) {
        self.baby = baby
        let request: NSFetchRequest<CustomEventType> = CustomEventType.fetchRequest()
        request.predicate = NSPredicate(format: "profile == %@", baby)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        _eventTypes = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        NavigationView {
            List {
                if eventTypes.isEmpty {
                    ContentUnavailableView(
                        "No Custom Event Types",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create custom event types to track activities like baths, medicine, or anything else!")
                    )
                } else {
                    ForEach(eventTypes) { eventType in
                        Button {
                            eventTypeToEdit = eventType
                        } label: {
                            HStack(spacing: 12) {
                                Text(eventType.emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(eventType.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    let count = eventType.eventsArray.count
                                    Text("\(count) event\(count == 1 ? "" : "s") logged")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                attemptDelete(eventType)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Custom Event Types")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Add Event Type"))
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddCustomEventTypeSheet(baby: baby) {
                    isShowingAddSheet = false
                }
                .environment(\.managedObjectContext, viewContext)
            }
            .sheet(item: $eventTypeToEdit) { eventType in
                EditCustomEventTypeSheet(eventType: eventType) {
                    eventTypeToEdit = nil
                }
                .environment(\.managedObjectContext, viewContext)
            }
            .alert("Cannot Delete", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
            .alert(item: $eventTypeToDelete) { eventType in
                Alert(
                    title: Text("Delete \(eventType.emoji) \(eventType.name)?"),
                    message: Text("This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteEventType(eventType)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func attemptDelete(_ eventType: CustomEventType) {
        let eventsCount = eventType.eventsArray.count
        if eventsCount > 0 {
            deleteErrorMessage = "Cannot delete '\(eventType.name)' because it has \(eventsCount) logged event\(eventsCount == 1 ? "" : "s"). Delete the events first."
            showDeleteError = true
        } else {
            eventTypeToDelete = eventType
        }
    }
    
    private func deleteEventType(_ eventType: CustomEventType) {
        viewContext.delete(eventType)
        do {
            try viewContext.save()
            NearbySyncManager.shared.sendPing()
        } catch {
            // Handle error
            print("Error deleting event type: \(error)")
        }
    }
}

struct AddCustomEventTypeSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let baby: BabyProfile
    let onSave: () -> Void
    
    @State private var name: String = ""
    @State private var emoji: String = ""
    @FocusState private var isNameFocused: Bool
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Name") {
                    TextField("e.g. Vomit, Bath, Medicine", text: $name)
                        .focused($isNameFocused)
                }
                
                Section {
                    TextField("Tap to add emoji", text: $emoji)
                        .font(.system(size: 48))
                        .multilineTextAlignment(.center)
                        .onChange(of: emoji) { _, newValue in
                            emoji = newValue.onlyEmoji()
                        }
                    
                    if !emoji.isEmpty && !emoji.isEmoji {
                        Text("Please enter a single emoji")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Emoji")
                }
                
                Section {
                    Text("Custom events let you track any activity for \(baby.name).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Event Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onSave()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let eventType = CustomEventType(context: viewContext, name: trimmedName, emoji: trimmedEmoji)
        eventType.profile = baby
        baby.addToCustomEventTypes(eventType)
        
        do {
            try viewContext.save()
            NearbySyncManager.shared.sendPing()
        } catch {
            print("Error saving event type: \(error)")
        }
        
        onSave()
        dismiss()
    }
}

struct EditCustomEventTypeSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let eventType: CustomEventType
    let onDismiss: () -> Void
    
    @State private var name: String = ""
    @State private var emoji: String = ""
    @FocusState private var isNameFocused: Bool
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Event Name") {
                    TextField("e.g. Vomit, Bath, Medicine", text: $name)
                        .focused($isNameFocused)
                }
                
                Section {
                    TextField("Tap to edit emoji", text: $emoji)
                        .font(.system(size: 48))
                        .multilineTextAlignment(.center)
                        .onChange(of: emoji) { _, newValue in
                            emoji = newValue.onlyEmoji()
                        }
                    
                    if !emoji.isEmpty && !emoji.isEmoji {
                        Text("Please enter a single emoji")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Emoji")
                }
                
                Section {
                    let count = eventType.eventsArray.count
                    Text("\(count) event\(count == 1 ? "" : "s") logged with this type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Event Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                name = eventType.name
                emoji = eventType.emoji
            }
        }
    }
    
    private func save() {
        eventType.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        eventType.emoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try viewContext.save()
            NearbySyncManager.shared.sendPing()
        } catch {
            print("Error updating event type: \(error)")
        }
        
        onDismiss()
        dismiss()
    }
}
