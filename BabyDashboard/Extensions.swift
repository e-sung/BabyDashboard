import Foundation
import SwiftUI

import Model

// A global computed property to determine the volume unit based on the user's locale.
var currentVolumeUnitSymbol: String {
    UnitUtils.preferredUnit.symbol
}

// An extension to easily convert a Double to a Measurement<UnitVolume>.
extension Double {
    func convertToCurrentVolumeUnit() -> Measurement<UnitVolume> {
        Measurement(value: self, unit: UnitUtils.preferredUnit)
    }
}

extension View {
    @ViewBuilder
    func applyDynamicTypeSize(_ size: DynamicTypeSize?) -> some View {
        if let size = size {
            self.dynamicTypeSize(size)
        } else {
            self
        }
    }

    /// Constrains readable width and adaptive horizontal padding, similar to iOS readable content guides.
    func readableContentWidth(
        maxWidth: CGFloat = 820,
        iPadPadding: CGFloat = 32,
        iPhonePadding: CGFloat = 0
    ) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth, iPadPadding: iPadPadding, iPhonePadding: iPhonePadding))
    }
}

private struct ReadableContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let maxWidth: CGFloat
    let iPadPadding: CGFloat
    let iPhonePadding: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: hSizeClass == .regular ? maxWidth : .infinity, alignment: .center)
            .padding(.horizontal, horizontalPadding)
    }

    private var horizontalPadding: CGFloat {
        guard hSizeClass == .regular else { return iPhonePadding }
        return iPadPadding * paddingScale(for: dynamicTypeSize)
    }

    private func paddingScale(for size: DynamicTypeSize) -> CGFloat {
        if size.isAccessibilitySize { return 0.6 }
        switch size {
        case .xSmall, .small, .medium:
            return 1.0
        case .large:
            return 0.9
        case .xLarge:
            return 0.85
        case .xxLarge:
            return 0.8
        default:
            return 0.7
        }
    }
}
