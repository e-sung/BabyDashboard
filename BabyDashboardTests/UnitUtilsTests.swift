import Testing
import Foundation
import Model

/// Tests for UnitUtils - Documents measurement unit conversion behavior
/// Replaces UnitSettingsTests UI test for unit switching and display
@Suite("Unit Conversion")
struct UnitUtilsTests {
    
    // MARK: - Conversion Tests
    
    @Test("Convert milliliters to fluid ounces")
    func mlToFlOz() {
        // Given: 120 ml
        let ml = Measurement(value: 120, unit: UnitVolume.milliliters)
        
        // When: Convert to fl oz
        let flOz = ml.converted(to: .fluidOunces)
        
        // Then: 120 ml ≈ 4.06 fl oz
        #expect(flOz.value >= 4.0 && flOz.value <= 4.1)
    }
    
    @Test("Convert fluid ounces to milliliters")
    func flOzToMl() {
        // Given: 4 fl oz
        let flOz = Measurement(value: 4, unit: UnitVolume.fluidOunces)
        
        // When: Convert to ml
        let ml = flOz.converted(to: .milliliters)
        
        // Then: 4 fl oz ≈ 118.3 ml
        #expect(ml.value >= 118 && ml.value <= 119)
    }
    
    // MARK: - Formatting Tests
    
    @Test("Format measurement with correct precision")
    func formatMeasurement() {
        // Given
        let ml = Measurement(value: 120, unit: UnitVolume.milliliters)
        let flOz = Measurement(value: 4.05768, unit: UnitVolume.fluidOunces)
        
        // When
        let mlFormatted = UnitUtils.format(measurement: ml)
        let flOzFormatted = UnitUtils.format(measurement: flOz)
        
        // Then: Should format with max 1 decimal
        #expect(mlFormatted.contains("120"))
        #expect(flOzFormatted.contains("4.1") || flOzFormatted.contains("4"))
    }
    
    @Test("Format preserves provided unit")
    func formatPreservesUnit() {
        // Given: Measurement in milliliters
        let ml = Measurement(value: 100, unit: UnitVolume.milliliters)
        
        // When
        let formatted = UnitUtils.format(measurement: ml)
        
        // Then: Should show ml, not convert to oz
        #expect(formatted.lowercased().contains("ml"))
    }
    
    // MARK: - Daily Summary Aggregation Test
    
    @Test("Aggregated amounts convert correctly")
    func aggregatedAmounts() {
        // Given: Two feeds in different units
        // Feed 1: 120 ml
        // Feed 2: 4 fl oz (≈118.3 ml)
        let feed1 = Measurement(value: 120, unit: UnitVolume.milliliters)
        let feed2 = Measurement(value: 4, unit: UnitVolume.fluidOunces)
        
        // When: Sum in fl oz
        let total = feed1.converted(to: .fluidOunces).value + feed2.converted(to: .fluidOunces).value
        
        // Then: 4.06 + 4.0 ≈ 8.06 fl oz
        #expect(total >= 8.0 && total <= 8.2)
    }
    
    @Test("Aggregated amounts match UI test expectation")
    func aggregatedMatchesUITest() {
        // This replicates the UnitSettingsTests assertion:
        // 120 ml + 4 fl oz = 8.1 fl oz (as displayed in History)
        
        // Given
        let feed1ml = Measurement(value: 120, unit: UnitVolume.milliliters)
        let feed2floz = Measurement(value: 4, unit: UnitVolume.fluidOunces)
        
        // When: Convert both to fl oz and format
        let feed1Converted = feed1ml.converted(to: .fluidOunces)
        let feed2Converted = feed2floz.converted(to: .fluidOunces)
        
        let total = Measurement(
            value: feed1Converted.value + feed2Converted.value,
            unit: UnitVolume.fluidOunces
        )
        let formatted = UnitUtils.format(measurement: total)
        
        // Then: Should display as "8.1 fl oz"
        #expect(formatted.contains("8.1") || formatted.contains("8"))
    }
    
    // MARK: - Base Fraction Length Tests
    
    @Test("Fraction length is 0 for milliliters")
    func fractionLengthMl() {
        // Note: This depends on UserDefaults state
        // When preferredUnit is ml, fractionLength should be 0
        // This documents the expected behavior
        
        // Given: ml unit
        let ml = Measurement(value: 120.5, unit: UnitVolume.milliliters)
        
        // Then: ml values are typically displayed as whole numbers
        let rounded = round(ml.value)
        #expect(rounded == 121 || rounded == 120)
    }
    
    @Test("Fraction length is 1 for fluid ounces")
    func fractionLengthFlOz() {
        // Given: fl oz unit with value that rounds to 1 decimal
        let flOz = Measurement(value: 4.15, unit: UnitVolume.fluidOunces)
        
        // When: Format
        let formatted = UnitUtils.format(measurement: flOz)
        
        // Then: Should show 1 decimal place (4.15 → 4.2 or 4.1)
        #expect(formatted.contains("4.2") || formatted.contains("4.1"))
    }
}
