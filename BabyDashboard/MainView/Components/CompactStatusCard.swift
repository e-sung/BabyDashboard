//
//  CompactStatusCard.swift
//  BabyDashboard
//
//  Created by 류성두 on 12/9/25.
//

import Foundation
import SwiftUI
import Model

// MARK: - Compact Square StatusCard for iPhone
struct CompactStatusCard: View {
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
    let accessibilityHintText: String
    let onTap: (() -> Void)?
    let onFooterTap: (() -> Void)?

    init(
        icon: StatusIcon,
        title: String,
        mainText: String,
        progressBarColor: Color,
        progress: Double,
        secondaryProgress: Double? = nil,
        secondaryProgressColor: Color? = nil,
        footerText: String,
        criteriaLabel: String = "",
        isAnimating: Bool = false,
        shouldWarn: Bool = false,
        warningColor: Color = .red,
        mainTextColor: Color? = nil,
        accessibilityHintText: String = "",
        onTap: (() -> Void)? = nil,
        onFooterTap: (() -> Void)? = nil
    ) {
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
        self.accessibilityHintText = accessibilityHintText
        self.onTap = onTap
        self.onFooterTap = onFooterTap
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(width: 44, height: 44)

                    switch icon {
                    case .emoji(let string):
                        Text(string)
                            .font(.title2)
                    case .image(let name):
                        Image(name)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundStyle(shouldWarn ? warningColor : .primary)
                    }
                }

                // Main Time Text
                Text(mainText)
                    .font(.title2.weight(.black))
                    .foregroundStyle(shouldWarn ? warningColor : (mainTextColor ?? .primary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                // Progress Bar
                CompactProgressBar(
                    progress: progress,
                    secondaryProgress: secondaryProgress,
                    progressBarColor: progressBarColor,
                    secondaryProgressColor: secondaryProgressColor,
                    criteriaLabel: criteriaLabel,
                    isAnimating: isAnimating
                )

                // Footer (tappable)
                Button {
                    onFooterTap?()
                } label: {
                    Text(footerText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.1), radius: 6, x: 2, y: 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(mainText)"))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(UnitUtils.baseFractionLength))))
        .accessibilityHint(Text(accessibilityHintText))
        .accessibilityAction(named: "Edit Details") {
            onFooterTap?()
        }
        .accessibilityAddTraits(.isButton)
    }
}

private struct CompactProgressBar: View {
    let progress: Double
    let secondaryProgress: Double?
    let progressBarColor: Color
    let secondaryProgressColor: Color?
    let criteriaLabel: String
    let isAnimating: Bool

    var body: some View {
        HStack(spacing: 2) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background Track
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: 4)

                    // Main Progress Bar
                    Capsule()
                        .fill(progressBarColor)
                        .frame(width: geometry.size.width * CGFloat(min(progress, 1.0)), height: 4)
                        .opacity(progress > 1.0 ? 0.3 : 1.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)

                    // Secondary Progress Bar
                    if let secondaryProgress, let secondaryProgressColor, progress < 1.0 {
                        Capsule()
                            .fill(secondaryProgressColor)
                            .frame(width: geometry.size.width * CGFloat(min(secondaryProgress, 1.0)), height: 4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: secondaryProgress)
                    }

                    // Overdue Progress Bar
                    if progress > 1.0 {
                        Capsule()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * CGFloat(min(progress - 1.0, 1.0)), height: 4)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                    }
                }
            }
            .frame(height: 4)
            .scaleEffect(isAnimating ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)

            Text(criteriaLabel)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}



#Preview("CompactStatusCard") {
    CompactStatusCard(
        icon: .emoji("🍼"),
        title: "Feeding",
        mainText: "2h 15m",
        progressBarColor: .blue,
        progress: 0.6,
        secondaryProgress: 0.8,
        secondaryProgressColor: .blue.opacity(0.3),
        footerText: "Edit",
        criteriaLabel: "3h",
        accessibilityHintText: "Opens feeding details"
    )
    .frame(width: 200, height: 200)
}
