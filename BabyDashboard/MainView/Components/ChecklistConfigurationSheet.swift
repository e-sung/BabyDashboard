import SwiftUI
import Model

struct ChecklistConfigurationSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let baby: BabyProfile
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CustomEventType.createdAt, ascending: true)],
        animation: .default)
    private var eventTypes: FetchedResults<CustomEventType>
    
    @State private var showingManagement = false
    
    private var currentEventTypeEmojis: Set<String> {
        Set(baby.dailyChecklistArray.map { $0.eventTypeEmoji })
    }
    
    init(baby: BabyProfile) {
        self.baby = baby
    }
    
    private func isInChecklist(_ eventType: CustomEventType) -> Bool {
        currentEventTypeEmojis.contains(eventType.emoji)
    }
    
    private func canAddMore() -> Bool {
        currentEventTypeEmojis.count < AppSettings.maxChecklistItems
    }
    
    private func addToChecklist(eventType: CustomEventType) {
        let maxOrder = baby.dailyChecklistArray.map(\.order).max() ?? -1
        _ = DailyChecklist(context: viewContext, baby: baby,
                          eventTypeName: eventType.name,
                          eventTypeEmoji: eventType.emoji,
                          order: maxOrder + 1)
        do {
            try viewContext.save()
            NearbySyncManager.shared.sendPing()
        } catch {
            print("Error adding to checklist: \(error)")
        }
    }
    
    private func removeFromChecklist(eventType: CustomEventType) {
        if let item = baby.dailyChecklistArray.first(where: { $0.eventTypeEmoji == eventType.emoji }) {
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
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(eventType.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                    }
                                    
                                    Spacer()
                                    
                                    if isConfigured {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    } else if !canAddMore() {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.gray.opacity(0.3))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canToggle)
                            .opacity(canToggle ? 1.0 : 0.5)
                        }
                    } header: {
                        Text("Select event types for daily checklist (\(currentEventTypeEmojis.count)/\(AppSettings.maxChecklistItems))")
                    } footer: {
                        if !canAddMore() {
                            Text("Maximum of \(AppSettings.maxChecklistItems) items reached. Remove an item to add another.")
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
#Preview {
    do {
        let context = PersistenceController.preview.container.viewContext
        let baby = BabyProfile(context: context, name: "Test Baby")
        
        // Create a sample custom event type
        let eventType1 = CustomEventType(context: context, name: "Vitamin", emoji: "💊")
        
        // Add to baby's checklist
        let item1 = DailyChecklist(context: context, baby: baby,
                                  eventTypeName: eventType1.name,
                                  eventTypeEmoji: eventType1.emoji,
                                  order: 0)
        baby.addToDailyChecklist(item1)
        try context.save()
        
        return ChecklistConfigurationSheet(baby: baby)
            .environment(\.managedObjectContext, context)
    } catch {
        return Text("Preview Error")
    }
}
#endif
