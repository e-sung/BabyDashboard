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
}
