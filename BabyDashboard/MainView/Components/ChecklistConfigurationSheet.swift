import SwiftUI
import CoreData
import Model

struct ChecklistConfigurationSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let baby: BabyProfile
    let maxItems: Int
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)],
        animation: .default
    )
    private var eventTypes: FetchedResults<CustomEventType>
    
    @State private var showingManagement = false
    
    private var currentEventTypeIDs: [UUID] {
        baby.dailyChecklistArray.map { $0.eventType.id }
    }
    
    init(
        baby: BabyProfile,
        maxItems: Int
    ) {
        self.baby = baby
        self.maxItems = maxItems
    }
    
    private func isInChecklist(_ eventType: CustomEventType) -> Bool {
        currentEventTypeIDs.contains(eventType.id)
    }
    
    private func canAddMore() -> Bool {
        currentEventTypeIDs.count < maxItems
    }
    
    private func addToChecklist(eventType: CustomEventType) {
        let maxOrder = baby.dailyChecklistArray.map(\.order).max() ?? -1
        _ = DailyChecklist(context: viewContext, baby: baby, eventType: eventType, order: maxOrder + 1)
        do {
            try viewContext.save()
            NearbySyncManager.shared.sendPing()
        } catch {
            print("Error adding to checklist: \(error)")
        }
    }
    
    private func removeFromChecklist(eventType: CustomEventType) {
        if let item = baby.dailyChecklistArray.first(where: { $0.eventType.id == eventType.id }) {
            viewContext.delete(item)
            do {
                try viewContext.save()
                NearbySyncManager.shared.sendPing()
            } catch {
                print("Error removing from checklist: \(error)")
            }
        }
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
                                    removeFromChecklist(eventType: eventType)
                                } else if canAddMore() {
                                    addToChecklist(eventType: eventType)
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

        let baby = BabyProfile(context: context, name: "Test Baby")
        let eventType1 = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        
        // Add to baby's checklist
        _ = DailyChecklist(context: context, baby: baby, eventType: eventType1, order: 0)

        return ChecklistConfigurationSheet(
            baby: baby,
            maxItems: 3
        )
        .environment(\.managedObjectContext, context)
    }
}
#endif

