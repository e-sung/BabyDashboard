
# Tech Spec: Baby Profile Refactoring

This document outlines the plan to refactor the app to support configurable baby profiles, removing the hardcoded baby names.

## 1. Current Status & Problem

The current implementation hardcodes the names and data for two babies, "연두" (Yeondoo) and "초원" (Chowon). This is not scalable and prevents users from customizing the app for their own needs.

The hardcoding is prevalent in the following files:

*   **`FullScreenClock/ContentView.swift`**:
    *   `ContentViewModel` has dedicated, duplicated properties for each baby (e.g., `연두수유시간`, `초원수유시간`).
    *   `UserDefaults` keys are hardcoded strings (`"연두수유시간"`, `"초원수유시간"`).
    *   The main view creates two `BabyStatusView` instances with hardcoded names and data bindings.
    *   Update logic is duplicated for each baby (e.g., `update연두수유시간()`, `update초원수유시간()`).

*   **`FullScreenClock/SiriIntents.swift`**:
    *   Separate Siri intent definitions exist for each baby (`UpdateYeondooFeedingTimeIntent`, `UpdateChowonFeedingTimeIntent`).
    *   Intent titles, descriptions, and shortcut phrases are hardcoded with the baby names.

This approach makes it impossible to add, remove, or rename babies without changing the source code.

## 2. Refactoring Strategy

We will introduce a `BabyProfile` model and refactor the app to use a list of these profiles dynamically.

### 2.1. Data Model

1.  **`BabyProfile`**: A new `Codable` struct to represent a baby.
    ```swift
    struct BabyProfile: Identifiable, Codable, Hashable {
        let id: UUID
        var name: String
        // Other properties like photo URL can be added later.
    }
    ```

2.  **`BabyState`**: A new class to hold the dynamic state for each baby.
    ```swift
    class BabyState: ObservableObject, Identifiable {
        let profile: BabyProfile
        @Published var lastFeedingTime: Date?
        @Published var elapsedTime: String = ""
        @Published var isWarning: Bool = false
        @Published var progress: Double = 0.0

        // ... initializer and methods ...
    }
    ```

### 2.2. ViewModel and Data Persistence

1.  **`ContentViewModel`**:
    *   Remove all baby-specific properties (e.g., `연두수유시간`, `초원수유시간`).
    *   Add a single published property to hold the state for all babies:
        ```swift
        @Published var babyStates: [BabyState] = []
        ```
    *   Refactor the timer and update logic to iterate through the `babyStates` array and update each `BabyState` object.

2.  **`UserDefaults`**:
    *   **Profiles**: The array of `BabyProfile`s will be encoded to JSON and saved to `UserDefaults`.
    *   **Feeding Times**: Each baby's last feeding time will be saved using their unique `profile.id` as the key, ensuring data integrity even if names change.

### 2.3. View Layer

*   The main `ContentView` will iterate over the `babyStates` array from the `ContentViewModel` to dynamically generate a `BabyStatusView` for each baby.
    ```swift
    ForEach(viewModel.babyStates) { babyState in
        BabyStatusView(babyState: babyState)
        // ...
    }
    ```
*   `BabyStatusView` will be updated to accept a `BabyState` object instead of individual properties.

### 2.4. Siri Intents

*   The separate intents will be consolidated into a single, more dynamic `UpdateFeedingTimeIntent`.
*   This intent will need to be configured with a `BabyProfile` parameter.
*   We will use App Intents with dynamic options to allow users to select which baby to update via Siri. This involves:
    1.  Defining an `AppEntity` for `BabyProfile`.
    2.  Creating an `EntityQuery` to provide a list of available babies to Siri.
    3.  Updating the intent definition to accept a `BabyProfile` entity as a parameter.

## 3. UI for Profile Management

As suggested, tapping the baby's name in the `BabyStatusView` will trigger the profile management UI.

### 3.1. UI Flow

1.  **Entry Point**: The `name` `Text` view in `BabyStatusView` will be wrapped in a `Button` or given a `.onTapGesture` modifier.
2.  **Presentation**: Tapping the name will present a modal sheet containing the `ProfileManagementView`.
3.  **`ProfileManagementView`**: This view will display a list of current baby profiles.
    *   It will have an "Add Baby" button.
    *   Each profile in the list will have "Edit" and "Delete" buttons.
    *   The list will support reordering (e.g., using `onMove`).
4.  **`ProfileEditView`**:
    *   Presented when adding a new baby or editing an existing one.
    *   Contains a `TextField` for the baby's name and a "Save" button.

### 3.2. Visual Plan (Based on Screenshots)

*   The main screen will show two `BabyStatusView`s side-by-side, as it does now.
*   Tapping a name (e.g., "연두") will present a modal view for profile management.
*   This modal will list the profiles ("연두", "초원").
*   Users can add, edit, delete, or reorder these profiles. The changes will be saved to `UserDefaults` and the main view will update accordingly.

This refactoring will create a flexible and user-friendly foundation for the app, allowing for future enhancements to the baby profile system.

## 4. Xcode Previews for Testing

To ensure a robust and maintainable UI, we will leverage Xcode Previews with mock data. This allows for rapid development and testing of different UI states without needing to run the full application or manipulate `UserDefaults`.

### 4.1. Mock Data Generation

We will create a static extension or a separate file to generate mock data for our models.

```swift
extension BabyProfile {
    static let mock1 = BabyProfile(id: UUID(), name: "아기 1")
    static let mock2 = BabyProfile(id: UUID(), name: "아기 2")
}

extension BabyState {
    static func mock(profile: BabyProfile, lastFed: Date? = nil) -> BabyState {
        let state = BabyState(profile: profile)
        state.lastFeedingTime = lastFed
        // Manually set other properties for specific scenarios
        return state
    }
}
```

### 4.2. Preview Scenarios

We will create previews for our views to test various core scenarios.

1.  **`BabyStatusView` Previews**:
    *   **Default State**: A baby that has not been fed yet.
    *   **Recently Fed**: A baby that was fed a few minutes ago.
    *   **Warning State**: A baby that was fed more than 3 hours ago, triggering the warning state.

    ```swift
    #if DEBUG
    struct BabyStatusView_Previews: PreviewProvider {
        static var previews: some View {
            VStack {
                BabyStatusView(babyState: BabyState.mock(profile: .mock1))
                BabyStatusView(babyState: BabyState.mock(profile: .mock2, lastFed: Date().addingTimeInterval(-60 * 5)))
                BabyStatusView(babyState: BabyState.mock(profile: .mock1, lastFed: Date().addingTimeInterval(-3601)))
            }
        }
    }
    #endif
    ```

2.  **`ContentView` Previews**:
    *   **Empty State**: The view when no baby profiles are configured.
    *   **Populated State**: The main view with one or more baby profiles.

    ```swift
    #if DEBUG
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            // Preview with a mock view model
            ContentView(viewModel: createMockViewModel())
        }

        static func createMockViewModel() -> ContentViewModel {
            let vm = ContentViewModel()
            let baby1 = BabyProfile(id: UUID(), name: "연두")
            let baby2 = BabyProfile(id: UUID(), name: "초원")
            vm.babyStates = [
                BabyState.mock(profile: baby1, lastFed: Date().addingTimeInterval(-120)),
                BabyState.mock(profile: baby2, lastFed: Date().addingTimeInterval(-7200))
            ]
            return vm
        }
    }
    #endif
    ```

3.  **`ProfileManagementView` Previews**:
    *   A preview of the profile management sheet with a list of mock profiles.

By implementing these previews, we can develop and verify the UI components in isolation, leading to a more stable and predictable user experience.
