import SwiftUI
import CoreData
import Model

struct ChecklistConfigurationSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let maxItems: Int
    let currentEventTypeIDs: [UUID]
    let onAdd: (CustomEventType) -> Void
    let onRemove: (UUID) -> Void
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)],
        animation: .default
    )
    private var eventTypes: FetchedResults<CustomEventType>
    
    @State private var showingManagement = false
    
    init(
        maxItems: Int,
        currentEventTypeIDs: [UUID],
        onAdd: @escaping (CustomEventType) -> Void,
        onRemove: @escaping (UUID) -> Void
    ) {
        self.maxItems = maxItems
        self.currentEventTypeIDs = currentEventTypeIDs
        self.onAdd = onAdd
        self.onRemove = onRemove
    }
    
    private func isInChecklist(_ eventType: CustomEventType) -> Bool {
        currentEventTypeIDs.contains(eventType.id)
    }
    
    private func canAddMore() -> Bool {
        currentEventTypeIDs.count < maxItems
    }
    
    var body: some View {
        NavigationView {
            List {
                if eventTypes.isEmpty {
                    ContentUnavailableView(
                        "No Custom Event Types",
                        systemImage: "calendar.badge.plus",
                        description: Text("Create custom event types to use as daily checklist items.")
                    )
                } else {
                    Section {
                        ForEach(eventTypes) { eventType in
                            let isConfigured = isInChecklist(eventType)
                            let canToggle = isConfigured || canAddMore()
                            
                            Button {
                                if isConfigured {
                                    onRemove(eventType.id)
                                } else if canAddMore() {
                                    onAdd(eventType)
                                }
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
                                    
                                    if isConfigured {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                            .font(.title3)
                                    } else if !canAddMore() {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.title3)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .disabled(!canToggle)
                            .opacity(canToggle ? 1.0 : 0.5)
                        }
                    } header: {
                        Text("Select event types for daily checklist (\(currentEventTypeIDs.count)/\(maxItems))")
                    } footer: {
                        if !canAddMore() {
                            Text("Maximum of \(maxItems) items reached. Remove an item to add another.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Button {
                        showingManagement = true
                    } label: {
                        Label("Manage Event Types", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Daily Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingManagement) {
                CustomEventTypeManagementView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
}

#if DEBUG
struct ChecklistConfigurationSheet_Previews: PreviewProvider {
    static var previews: some View {
        let controller = PersistenceController.preview
        let context = controller.viewContext

        let eventType1 = CustomEventType(context: context, name: "Vitamin", emoji: "💊")


        return ChecklistConfigurationSheet(
            maxItems: 3,
            currentEventTypeIDs: [eventType1.id], // Vitamin is already in checklist
            onAdd: { _ in },
            onRemove: { _ in }
        )
        .environment(\.managedObjectContext, context)
    }
}
#endif

