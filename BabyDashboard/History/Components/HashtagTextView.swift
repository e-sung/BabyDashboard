import SwiftUI
import UIKit

struct HashtagTextView: UIViewRepresentable {
    @Binding var text: String
    // When set, the view will insert the string at the current caret and clear it.
    @Binding var pendingInsertion: String?
    var hashtagAttributes: [NSAttributedString.Key: Any]

    // New: provide recent hashtags to render in an inputAccessoryView
    var recentHashtags: [String]

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.delegate = context.coordinator
        tv.textContainer.lineFragmentPadding = 0
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tv.keyboardDismissMode = .interactive

        // Initial content
        context.coordinator.updateAttributedText(in: tv, text: text, attributes: hashtagAttributes)

        // Build initial accessory
        context.coordinator.installAccessory(on: tv,
                                             recentHashtags: recentHashtags,
                                             onInsert: { tag in
            DispatchQueue.main.async {
                self.pendingInsertion = (tag.hasPrefix("#") ? tag : "#\(tag)") + " "
            }
        })

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Insert pending text at caret if requested
        if let insertion = pendingInsertion {
            if let selectedRange = uiView.selectedTextRange {
                uiView.replace(selectedRange, withText: insertion)
                // Update binding text to reflect the insertion
                text = uiView.text
            }
            DispatchQueue.main.async {
                pendingInsertion = nil
            }
        }

        // Keep attributed text in sync if needed
        if uiView.text != text || context.coordinator.needsRehighlight {
            // Preserve selection
            let selected = uiView.selectedRange
            context.coordinator.updateAttributedText(in: uiView, text: text, attributes: hashtagAttributes)
            // Restore selection safely
            let maxLoc = (uiView.attributedText?.length ?? 0)
            let newLocation = min(selected.location, maxLoc)
            let newLength = min(selected.length, max(0, maxLoc - newLocation))
            uiView.selectedRange = NSRange(location: newLocation, length: newLength)
        }

        // Update accessory if the hashtag list changed
        if context.coordinator.lastRenderedHashtags != recentHashtags {
            context.coordinator.installAccessory(on: uiView,
                                                 recentHashtags: recentHashtags,
                                                 onInsert: { tag in
                DispatchQueue.main.async {
                    self.pendingInsertion = (tag.hasPrefix("#") ? tag : "#\(tag)") + " "
                }
            })
            // Ensure UIKit refreshes the accessory
            uiView.reloadInputViews()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var needsRehighlight: Bool = false

        // Keep a hosting controller so we can update accessory views efficiently
        fileprivate var hostingController: UIHostingController<AccessoryBarView>?
        var lastRenderedHashtags: [String] = []

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            needsRehighlight = true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // No-op
        }

        func updateAttributedText(in textView: UITextView, text: String, attributes: [NSAttributedString.Key: Any]) {
            let attributed = NSMutableAttributedString(string: text, attributes: [
                .font: textView.font as Any,
                .foregroundColor: UIColor.label
            ])
            // Highlight hashtags
            let pattern = #"(?<!\w)#([\p{L}\p{N}_]+)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let ns = text as NSString
                let range = NSRange(location: 0, length: ns.length)
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    guard let match else { return }
                    attributed.addAttributes(attributes, range: match.range(at: 0))
                }
            }
            textView.attributedText = attributed
            needsRehighlight = false
        }

        // Build or update the accessory bar
        func installAccessory(on textView: UITextView,
                              recentHashtags: [String],
                              onInsert: @escaping (String) -> Void) {
            lastRenderedHashtags = recentHashtags

            let view = AccessoryBarView(hashtags: recentHashtags, onInsert: onInsert)
            if let hosting = hostingController {
                hosting.rootView = view
                hosting.view.invalidateIntrinsicContentSize()
                hosting.view.setNeedsLayout()
                hosting.view.layoutIfNeeded()
                textView.inputAccessoryView = hosting.view
            } else {
                let hosting = UIHostingController(rootView: view)
                hosting.view.backgroundColor = .clear

                // Size the accessory to a standard toolbar height
                let height: CGFloat = 44
                hosting.view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height)

                hostingController = hosting
                textView.inputAccessoryView = hosting.view
            }
        }
    }
}

// MARK: - Accessory bar SwiftUI view

fileprivate struct AccessoryBarView: View {
    let hashtags: [String]
    let onInsert: (String) -> Void

    var body: some View {
        // If empty, show an unobtrusive bar to keep consistent height (or return EmptyView)
        if hashtags.isEmpty {
            Color.clear.frame(height: 0.1) // practically hidden
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(hashtags, id: \.self) { tag in
                        Button(action: { onInsert(tag) }) {
                            Text(tag.hasPrefix("#") ? tag : "#\(tag)")
                                .font(.callout)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Insert \(tag)"))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .background(.ultraThinMaterial)
            .frame(height: 44)
        }
    }
}

