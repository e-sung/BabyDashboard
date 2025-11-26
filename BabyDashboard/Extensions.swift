import Foundation
import SwiftUI

// A global computed property to determine the volume unit based on the user's locale.
var currentVolumeUnitSymbol: String {
    Locale.current.measurementSystem == .us ? "fl oz" : "ml"
}

// An extension to easily convert a Double to a Measurement<UnitVolume>.
extension Double {
    func convertToCurrentVolumeUnit() -> Measurement<UnitVolume> {
        let unit: UnitVolume = (Locale.current.measurementSystem == .us) ? .fluidOunces : .milliliters
        return Measurement(value: self, unit: unit)
    }
}
