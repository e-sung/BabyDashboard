import Foundation

public struct UnitUtils {
    private static let preferredUnitKey = "preferredUnit"
    
    public static var preferredUnit: UnitVolume {
        get {
            if let savedSymbol = UserDefaults.standard.string(forKey: preferredUnitKey) {
                return unit(from: savedSymbol)
            }
            // Default based on locale
            return Locale.current.measurementSystem == .us ? .fluidOunces : .milliliters
        }
        set {
            UserDefaults.standard.set(newValue.symbol, forKey: preferredUnitKey)
        }
    }

    public static var baseFractionLength: Int {
        if preferredUnit == .fluidOunces {
            return 1
        }
        return 0
    }

    public static func format(measurement: Measurement<UnitVolume>) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter.string(from: measurement)
    }
    
    private static func unit(from symbol: String) -> UnitVolume {
        switch symbol {
        case "fl oz": return .fluidOunces
        case "ml": return .milliliters
        default: return .milliliters
        }
    }
}
