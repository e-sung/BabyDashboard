import SwiftUI
import Model

enum StatusIcon {
    case emoji(String)
    case image(String)
}

struct StatusCard: View {
    let icon: StatusIcon
    let title: String
    let mainText: String
    let progressBarColor: Color
    let progress: Double
    let secondaryProgress: Double?
    let secondaryProgressColor: Color?
    let footerText: String
    let criteriaLabel: String
    let isAnimating: Bool
    let shouldWarn: Bool
    let warningColor: Color
    let mainTextColor: Color?

    // Accessibility
    let accessibilityCriteriaLabel: String?
    let accessibilityHintText: String
    let onTap: (() -> Void)?
    let onFooterTap: (() -> Void)?

    @Environment(\.sizeCategory) var sizeCategory

    init(icon: StatusIcon, title: String, mainText: String, progressBarColor: Color, progress: Double, secondaryProgress: Double? = nil, secondaryProgressColor: Color? = nil, footerText: String, criteriaLabel: String = "", isAnimating: Bool = false, shouldWarn: Bool = false, warningColor: Color = .red, mainTextColor: Color? = nil, accessibilityCriteriaLabel: String? = nil, accessibilityHintText: String = "", onTap: (() -> Void)? = nil, onFooterTap: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.mainText = mainText
        self.progressBarColor = progressBarColor
        self.progress = progress
        self.secondaryProgress = secondaryProgress
        self.secondaryProgressColor = secondaryProgressColor
        self.footerText = footerText
        self.criteriaLabel = criteriaLabel
        self.isAnimating = isAnimating
        self.shouldWarn = shouldWarn
        self.warningColor = warningColor
        self.mainTextColor = mainTextColor
        self.accessibilityCriteriaLabel = accessibilityCriteriaLabel
        self.accessibilityHintText = accessibilityHintText
        self.onTap = onTap
        self.onFooterTap = onFooterTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 24) {
                HeaderView(
                    icon: icon,
                    title: title,
                    mainText: mainText,
                    footerText: footerText,
                    shouldWarn: shouldWarn,
                    warningColor: warningColor,
                    mainTextColor: mainTextColor,
                    onFooterTap: onFooterTap
                )
                // Progress Bar
                ProgressBar(
                    progress: progress,
                    secondaryProgress: secondaryProgress,
                    progressBarColor: progressBarColor,
                    secondaryProgressColor: secondaryProgressColor,
                    criteriaLabel: criteriaLabel,
                    isAnimating: isAnimating
                )

            }
            .padding(40)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(20)
            .shadow(color: Color.primary.opacity(0.1), radius: 10, x: 5, y: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(mainText)"))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(UnitUtils.baseFractionLength))))
        .accessibilityHint(Text(accessibilityHintText))
        .accessibilityCustomContent("Last Session summary", footerText)
        .accessibilityCustomContent("Interval", criteriaLabel)
        .accessibilityAction(named: "Edit Details") {
            onFooterTap?()
        }
        .accessibilityAddTraits(.isButton)
    }


}

private struct HeaderView: View {
    let icon: StatusIcon
    let title: String
    let mainText: String
    let footerText: String
    let shouldWarn: Bool
    let warningColor: Color
    let mainTextColor: Color?
    let onFooterTap: (() -> Void)?
    
    private var isIPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: isIPad ? 12 : 6)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: isIPad ? 100 : 60, height: isIPad ? 100 : 60)

                switch icon {
                case .emoji(let string):
                    Text(string)
                        .font(isIPad ? .system(size: 65) : .largeTitle)
                        .dynamicTypeSize(.xxLarge)
                case .image(let name):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: isIPad ? 65 : 30, height: isIPad ? 65 : 30)
                        .foregroundStyle(shouldWarn ? warningColor : .primary)
                }
            }
            
            VStack(alignment: .leading, spacing: isIPad ? 8 : 4) {
                Button {
                    onFooterTap?()
                } label: {
                    HStack(alignment: .lastTextBaseline) {
                        Text(title)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        HStack(spacing: 4) {
                            Text(footerText)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                }
                .accessibilityLabel(footerText)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .font(isIPad ? .body : .caption)

                Text(mainText)
                    .font(isIPad ? .custom("Pretendard-Black", size: 70, relativeTo: .largeTitle) : .largeTitle.weight(.black))
                    .foregroundStyle(shouldWarn ? warningColor : (mainTextColor ?? .primary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

private struct ProgressBar: View {
    let progress: Double
    let secondaryProgress: Double?
    let progressBarColor: Color
    let secondaryProgressColor: Color?
    let criteriaLabel: String
    let isAnimating: Bool
    
    private var isIPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: isIPad ? 12 : 6)
                    
                    // Main Progress Bar
                    Capsule()
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)), height: isIPad ? 12 : 6)
                        .opacity(progress > 1.0 ? 0.3 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                    
                    // Secondary Progress Bar (Overlay)
                    if let secondaryProgress, let secondaryProgressColor, progress < 1.0 {
                        Capsule()
                            .fill(secondaryProgressColor)
                            .frame(width: geometry.size.width * CGFloat(min(secondaryProgress, 1.0)), height: isIPad ? 12 : 6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: secondaryProgress)
                    }
                    
                    // Overdue Progress Bar
                    if progress > 1.0 {
                        Capsule()
                            .fill(Color.red) // Default overdue color
                            .frame(width: geometry.size.width * CGFloat(min(progress - 1.0, 1.0)), height: isIPad ? 12 : 6)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                    }
                }
            }
            .frame(height: isIPad ? 12 : 6)
            .scaleEffect(isAnimating ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
            
            Text(criteriaLabel)
                .font(isIPad ? .title3 : .caption)
                .foregroundColor(.secondary)
                .dynamicTypeSize(.large)
        }
    }
}

#if DEBUG
struct StatusCard_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                StatusCard(
                    icon: .emoji("🍼"),
                    title: "Last Feed",
                    mainText: "2시간 20분 전",
                    progressBarColor: .green,
                    progress: 0.7,
                    secondaryProgress: 0.3,
                    secondaryProgressColor: .blue,
                    footerText: "2:26 • 140ml",
                    criteriaLabel: "3h"
                )
            }
            .previewDisplayName("Feed Card")
            
            StatusCard(
                icon: .image("diaper"), // Note: Image might not load if asset doesn't exist in preview context, but logic holds
                title: "DIAPER",
                mainText: "30m ago",
                progressBarColor: .purple,
                progress: 0.3,
                footerText: "Last: 4:36",
                criteriaLabel: "3h"
            )
            .previewDisplayName("Diaper Card")
            
            StatusCard(
                icon: .emoji("🍼"),
                title: "OVERDUE FEED",
                mainText: "3h 20m ago",
                progressBarColor: .blue,
                progress: 1.1, // 110%
                footerText: "Last: 2:26 • 140ml",
                criteriaLabel: "3h",
                shouldWarn: true
            )
            .previewDisplayName("Overdue Card")
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .previewLayout(.sizeThatFits)
        .environment(\.colorScheme, .dark)
    }
}
#endif

