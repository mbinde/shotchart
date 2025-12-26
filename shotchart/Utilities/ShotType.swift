import Foundation

enum ShotType: Int16, CaseIterable {
    case twoPointer = 0
    case threePointer = 1
    case freeThrow = 2

    var displayName: String {
        switch self {
        case .twoPointer: return "2PT"
        case .threePointer: return "3PT"
        case .freeThrow: return "FT"
        }
    }

    /// Calculate distance in feet from basket for normalized court position
    static func distanceFromBasket(x: Double, y: Double) -> Double {
        let basketX = 0.5
        let basketY = 5.25 / 47.0  // Basket is 5.25 feet from baseline
        let dxFeet = (x - basketX) * 50.0
        let dyFeet = (y - basketY) * 47.0
        return sqrt(dxFeet * dxFeet + dyFeet * dyFeet)
    }

    /// Detect shot type based on normalized court position (0-1 range)
    /// Court dimensions - 50' wide x 47' half court
    /// Basket at TOP center (0.5, 5.25/47 ≈ 0.112)
    /// - Parameters:
    ///   - x: Normalized x position (0-1)
    ///   - y: Normalized y position (0-1)
    ///   - threePointArc: 3-point arc distance in feet (varies by court type)
    ///   - threePointCorner: Corner 3-point distance in feet (NBA=22, College=21.65, HS=19.75)
    static func detect(x: Double, y: Double, threePointArc: Double = 23.75, threePointCorner: Double = 22.0) -> ShotType {
        // Basket: 5.25 feet from baseline (63 inches, standard for all levels)
        let basketX = 0.5
        let basketY = 5.25 / 47.0

        // Free throw line: 19 feet from baseline → 19/47 = 0.404
        let freeThrowY = 19.0 / 47.0
        let freeThrowTolerance = 2.0 / 47.0  // ~2 feet
        let freeThrowXRange = 6.0 / 50.0     // within 6 feet of center (inside key)

        if abs(y - freeThrowY) < freeThrowTolerance && abs(x - basketX) < freeThrowXRange {
            return .freeThrow
        }

        // Distance from basket (accounting for aspect ratio)
        // x is normalized to 50 feet, y to 47 feet
        let dxFeet = (x - basketX) * 50.0
        let dyFeet = (y - basketY) * 47.0
        let distanceFeet = sqrt(dxFeet * dxFeet + dyFeet * dyFeet)

        // Use slightly smaller thresholds to account for the line itself
        let arcThreshold = threePointArc - 0.25
        let cornerThreshold = threePointCorner - 0.5

        // Corner: within 3 feet of sideline (where corner 3 applies)
        let cornerZoneX = 3.0 / 50.0 + 0.02
        let isCorner = x < cornerZoneX || x > 1.0 - cornerZoneX

        if isCorner {
            return distanceFeet > cornerThreshold ? .threePointer : .twoPointer
        } else {
            return distanceFeet > arcThreshold ? .threePointer : .twoPointer
        }
    }
}
