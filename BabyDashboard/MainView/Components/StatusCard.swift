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
            VStack(alignment: .leading, spacing: isIPhone ? 16 : 24) {
                HeaderView(
                    icon: icon,
                    title: title,
                    mainText: mainText,
                    footerText: footerText,
                    shouldWarn: shouldWarn,
                    warningColor: warningColor,
                    mainTextColor: mainTextColor,
                    isIPhone: isIPhone,
                    onFooterTap: onFooterTap
                )
                // Progress Bar
                ProgressBar(
                    progress: progress,
                    secondaryProgress: secondaryProgress,
                    progressBarColor: progressBarColor,
                    secondaryProgressColor: secondaryProgressColor,
                    criteriaLabel: criteriaLabel,
                    isAnimating: isAnimating,
                    isIPhone: isIPhone
                )

            }
            .padding(isIPhone ? 24 : 40)
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
    
    private var isIPhone: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
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
    let isIPhone: Bool
    let onFooterTap: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: isIPhone ? 6 : 12)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: isIPhone ? 50 : 100, height: isIPhone ? 50 : 100)

                switch icon {
                case .emoji(let string):
                    Text(string)
                        .font(isIPhone ? .title : .system(size: 65))
                        .dynamicTypeSize(.xxLarge)
                case .image(let name):
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: isIPhone ? 25 : 65, height: isIPhone ? 25 : 65)
                        .foregroundStyle(shouldWarn ? warningColor : .primary)
                }
            }
            
            VStack(alignment: .leading, spacing: isIPhone ? 2 : 8) {
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
                .font(isIPhone ? .caption : .body)

                Text(mainText)
                    .font(isIPhone ? .title.weight(.black) : .custom("Pretendard-Black", size: 70, relativeTo: .largeTitle))
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
    let isIPhone: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: isIPhone ? 6 : 12)
                    
                    // Main Progress Bar
                    Capsule()
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)), height: isIPhone ? 6 : 12)
                        .opacity(progress > 1.0 ? 0.3 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                    
                    // Secondary Progress Bar (Overlay)
                    if let secondaryProgress, let secondaryProgressColor, progress < 1.0 {
                        Capsule()
                            .fill(secondaryProgressColor)
                            .frame(width: geometry.size.width * CGFloat(min(secondaryProgress, 1.0)), height: isIPhone ? 6 : 12)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: secondaryProgress)
                    }
                    
                    // Overdue Progress Bar
                    if progress > 1.0 {
                        Capsule()
                            .fill(Color.red) // Default overdue color
                            .frame(width: geometry.size.width * CGFloat(min(progress - 1.0, 1.0)), height: isIPhone ? 6 : 12)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                    }
                }
            }
            .frame(height: isIPhone ? 6 : 12)
            .scaleEffect(isAnimating ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
            
            Text(criteriaLabel)
                .font(isIPhone ? .caption : .title3)
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

