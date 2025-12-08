//
//  TokenSuggestionsOverlay.swift
//  BabyDashboard
//
//  Created by Antigravity on 12/08/25.
//

import SwiftUI

/// A search token that can be displayed and selected
protocol SearchableToken: Identifiable, Hashable {
    var displayText: String { get }
}

/// Custom token suggestions UI that overlays above the native search bar
/// Designed to mimic iOS 26 Photos app style
struct TokenSuggestionsOverlay<Token: SearchableToken>: View {
    let suggestedTokens: [Token]
    @Binding var selectedTokens: [Token]
    let isSearchActive: Bool
    
    var body: some View {
        if isSearchActive && !availableTokens.isEmpty {
            // Token suggestions - height fits content
            FlowLayout(spacing: 8, rowSpacing: 10) {
                ForEach(availableTokens, id: \.id) { token in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTokens.append(token)
                        }
                    } label: {
                        Text(token.displayText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String(format: String(localized: "Filter by %@"), token.displayText)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.bar)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSearchActive)
        }
    }
    
    private var availableTokens: [Token] {
        suggestedTokens.filter { suggestion in
            !selectedTokens.contains { $0.id == suggestion.id }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds a custom token suggestions overlay that appears above the native search bar
    func tokenSuggestionsOverlay<Token: SearchableToken>(
        suggestedTokens: [Token],
        selectedTokens: Binding<[Token]>,
        isSearchActive: Bool
    ) -> some View {
        self.safeAreaInset(edge: .bottom, spacing: 0) {
            TokenSuggestionsOverlay(
                suggestedTokens: suggestedTokens,
                selectedTokens: selectedTokens,
                isSearchActive: isSearchActive
            )
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewToken: SearchableToken {
        let id: String
        let displayText: String
    }
    
    struct PreviewContainer: View {
        @State private var text = ""
        @State private var tokens: [PreviewToken] = []
        @State private var isSearchActive = true
        
        let suggestions = [
            PreviewToken(id: "1", displayText: "🍼 Feed"),
            PreviewToken(id: "2", displayText: "💧 Pee"),
            PreviewToken(id: "3", displayText: "💩 Poo"),
            PreviewToken(id: "4", displayText: "😴 Nap"),
            PreviewToken(id: "5", displayText: "Baby A"),
            PreviewToken(id: "6", displayText: "Baby B"),
        ]
        
        var body: some View {
            NavigationView {
                List {
                    ForEach(1..<20) { i in
                        Text("Item \(i)")
                    }
                }
                .navigationTitle("History")
                .tokenSuggestionsOverlay(
                    suggestedTokens: suggestions,
                    selectedTokens: $tokens,
                    isSearchActive: isSearchActive
                )
                .searchable(text: $text)
            }

        }
    }
    
    return PreviewContainer()
}
