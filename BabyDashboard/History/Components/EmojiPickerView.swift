//
//  EmojiPickerView.swift
//  BabyDashboard
//
//  Reusable emoji picker with search and keyboard fallback
//

import SwiftUI

enum EmojiInputMode {
    case picker
    case keyboard
}

struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    @State private var searchText: String = ""
    @State private var inputMode: EmojiInputMode = .picker
    @FocusState private var isKeyboardFocused: Bool
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    
    private var filteredEmojis: [EmojiData] {
        EmojiDatabase.search(searchText)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Selected emoji display
            if !selectedEmoji.isEmpty {
                Text(selectedEmoji)
                    .font(.system(size: 64))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
            }
            
            // Input mode toggle
            Picker("Input Mode", selection: $inputMode) {
                Label("Picker", systemImage: "square.grid.3x3").tag(EmojiInputMode.picker)
                Label("Keyboard", systemImage: "keyboard").tag(EmojiInputMode.keyboard)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Emoji input mode")
            
            if inputMode == .picker {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search emoji (e.g., bath, medicine)", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("EmojiSearchField")
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(8)
                
                // Emoji grid
                ScrollView {
                    if filteredEmojis.isEmpty {
                        ContentUnavailableView(
                            "No matching emojis",
                            systemImage: "magnifyingglass",
                            description: Text("Try searching for 'bath', 'medicine', 'sleep', or other activities")
                        )
                        .padding()
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredEmojis) { emojiData in
                                Button {
                                    selectedEmoji = emojiData.emoji
                                } label: {
                                    Text(emojiData.emoji)
                                        .font(.system(size: 36))
                                        .frame(width: 48, height: 48)
                                        .background(
                                            selectedEmoji == emojiData.emoji ?
                                            Color.accentColor.opacity(0.2) :
                                            Color.clear
                                        )
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(emojiData.keywords.first ?? emojiData.emoji)
                                .accessibilityIdentifier("EmojiButton_\(emojiData.emoji)")
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .frame(minHeight: 300)
            } else {
                // Keyboard input mode
                VStack(spacing: 12) {
                    TextField("Tap to use emoji keyboard", text: $selectedEmoji)
                        .font(.system(size: 48))
                        .multilineTextAlignment(.center)
                        .focused($isKeyboardFocused)
                        .onChange(of: selectedEmoji) { _, newValue in
                            selectedEmoji = newValue.onlyEmoji()
                        }
                        .accessibilityIdentifier("EmojiKeyboardField")
                    
                    if !selectedEmoji.isEmpty && !selectedEmoji.isEmoji {
                        Text("Please enter a single emoji")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    Text("Use your device's emoji keyboard to select an emoji")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(minHeight: 300)
                .onAppear {
                    isKeyboardFocused = true
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedEmoji = ""
        
        var body: some View {
            NavigationView {
                Form {
                    Section("Emoji Picker") {
                        EmojiPickerView(selectedEmoji: $selectedEmoji)
                    }
                    
                    Section("Selected") {
                        Text("Emoji: \(selectedEmoji)")
                    }
                }
                .navigationTitle("Emoji Picker Demo")
            }
        }
    }
    
    return PreviewWrapper()
}
