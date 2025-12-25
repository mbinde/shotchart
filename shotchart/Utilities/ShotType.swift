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

    /// Detect shot type based on normalized court position (0-1 range)
    /// Court: NBA dimensions - 50' wide x 47' half court
    /// Basket at TOP center (0.5, 4/47 ≈ 0.085)
    static func detect(x: Double, y: Double) -> ShotType {
        // NBA dimensions in normalized coordinates
        // Basket: 4 feet from baseline → 4/47 = 0.085
        let basketX = 0.5
        let basketY = 4.0 / 47.0

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

        // 3-point line is 23.75 feet from basket (22 feet in corners)
        let threePointThreshold = 23.5  // feet
        let cornerThreeThreshold = 21.5 // feet (corners are slightly shorter)

        // Corner: within 3 feet of sideline
        let isCorner = x < (3.0 / 50.0) + 0.02 || x > 1.0 - (3.0 / 50.0) - 0.02

        if isCorner {
            return distanceFeet > cornerThreeThreshold ? .threePointer : .twoPointer
        } else {
            return distanceFeet > threePointThreshold ? .threePointer : .twoPointer
        }
    }
}
