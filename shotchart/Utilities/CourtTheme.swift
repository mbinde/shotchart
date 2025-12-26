import SwiftUI

// MARK: - Court Background Pattern

enum CourtBackgroundPattern: String, CaseIterable, Identifiable {
    // Row 1: Basic patterns
    case none = "none"
    case solid = "solid"
    case gradient = "gradient"
    case horizontalGradient = "horizontalGradient"
    // Row 2: Stripes
    case verticalStripes = "verticalStripes"
    case horizontalStripes = "horizontalStripes"
    case diagonalStripes = "diagonalStripes"
    case checkerboard = "checkerboard"
    // Row 3: Splits
    case halfVertical = "halfVertical"
    case halfHorizontal = "halfHorizontal"
    case diagonalSplit = "diagonalSplit"
    case quadrants = "quadrants"
    // Row 4: Advanced
    case radialGradient = "radialGradient"
    case radialFromBasket = "radialFromBasket"
    case zonesBased = "zonesBased"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .solid: return "Solid"
        case .verticalStripes: return "Vertical Stripes"
        case .horizontalStripes: return "Horizontal Stripes"
        case .diagonalStripes: return "Diagonal Stripes"
        case .gradient: return "Vertical Gradient"
        case .horizontalGradient: return "Horizontal Gradient"
        case .radialGradient: return "Radial Gradient"
        case .checkerboard: return "Checkerboard"
        case .quadrants: return "Quadrants"
        case .halfVertical: return "Half (Left/Right)"
        case .halfHorizontal: return "Half (Top/Bottom)"
        case .diagonalSplit: return "Diagonal Split"
        case .radialFromBasket: return "Rings from Basket"
        case .zonesBased: return "Shot Zones"
        }
    }

    var minColors: Int {
        switch self {
        case .none: return 0
        case .solid: return 1
        case .halfVertical, .halfHorizontal, .diagonalSplit: return 2
        case .quadrants: return 4
        default: return 2
        }
    }

    var maxColors: Int {
        switch self {
        case .none: return 0
        case .solid: return 1
        case .halfVertical, .halfHorizontal, .diagonalSplit: return 2
        case .quadrants: return 4
        case .zonesBased: return 6
        default: return 6
        }
    }

    var supportsScale: Bool {
        switch self {
        case .verticalStripes, .horizontalStripes, .diagonalStripes, .checkerboard:
            return true
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .none: return "No background, line colors only"
        case .solid: return "Single color background"
        case .verticalStripes: return "Vertical color stripes"
        case .horizontalStripes: return "Horizontal color stripes"
        case .diagonalStripes: return "Diagonal color stripes"
        case .gradient: return "Smooth color blend top to bottom"
        case .horizontalGradient: return "Smooth color blend left to right"
        case .radialGradient: return "Colors blend from center outward"
        case .checkerboard: return "Alternating color squares"
        case .quadrants: return "Four corner sections"
        case .halfVertical: return "Left and right halves"
        case .halfHorizontal: return "Top and bottom halves"
        case .diagonalSplit: return "Diagonal line divides colors"
        case .radialFromBasket: return "Concentric rings from the basket"
        case .zonesBased: return "Restricted, paint, mid-range, corner 3, above break, deep"
        }
    }
}

// MARK: - Court Theme

struct CourtTheme: Equatable {
    var backgroundColors: [Color]
    var backgroundAlpha: Float
    var lineColor: CourtLineColor
    var pattern: CourtBackgroundPattern
    var patternScale: Float

    static let `default` = CourtTheme(
        backgroundColors: [],
        backgroundAlpha: 1.0,
        lineColor: .white,
        pattern: .solid,
        patternScale: 1.0
    )

    /// Create theme from Team Core Data properties
    init(from team: Team?) {
        guard let team = team else {
            self = .default
            return
        }

        // Parse background colors from comma-separated hex string
        if let colorString = team.courtBackgroundColor, !colorString.isEmpty {
            self.backgroundColors = colorString
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .compactMap { Color(hex: $0) }
        } else {
            self.backgroundColors = []
        }

        // Background alpha
        self.backgroundAlpha = team.courtBackgroundAlpha > 0 ? team.courtBackgroundAlpha : 1.0

        // Line color
        if let lineColorString = team.courtLineColor {
            self.lineColor = CourtLineColor(from: lineColorString)
        } else {
            self.lineColor = .white
        }

        // Pattern
        if let patternString = team.courtBackgroundPattern,
           let pattern = CourtBackgroundPattern(rawValue: patternString) {
            self.pattern = pattern
        } else {
            self.pattern = .solid
        }

        // Pattern scale
        self.patternScale = team.courtPatternScale > 0 ? team.courtPatternScale : 1.0
    }

    init(backgroundColors: [Color], backgroundAlpha: Float, lineColor: CourtLineColor, pattern: CourtBackgroundPattern = .solid, patternScale: Float = 1.0) {
        self.backgroundColors = backgroundColors
        self.backgroundAlpha = backgroundAlpha
        self.lineColor = lineColor
        self.pattern = pattern
        self.patternScale = patternScale
    }

    var hasCustomBackground: Bool {
        !backgroundColors.isEmpty
    }
}

// MARK: - Court Line Color

enum CourtLineColor: Equatable {
    case white
    case black
    case custom(Color)

    var color: Color {
        switch self {
        case .white: return .white
        case .black: return .black
        case .custom(let color): return color
        }
    }

    init(from string: String) {
        switch string.lowercased() {
        case "white": self = .white
        case "black": self = .black
        default:
            if let color = Color(hex: string) {
                self = .custom(color)
            } else {
                self = .white
            }
        }
    }

    var stringValue: String {
        switch self {
        case .white: return "white"
        case .black: return "black"
        case .custom(let color): return color.toHex() ?? "white"
        }
    }
}

// MARK: - Color Hex Extensions

extension Color {
    /// Create a Color from a hex string (with or without #)
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count

        switch length {
        case 6: // RGB
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        case 8: // RGBA
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        default:
            return nil
        }
    }

    /// Convert Color to hex string
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }

        let r: CGFloat = components.count > 0 ? components[0] : 0
        let g: CGFloat = components.count > 1 ? components[1] : 0
        let b: CGFloat = components.count > 2 ? components[2] : 0

        return String(format: "#%02X%02X%02X",
                      Int(r * 255),
                      Int(g * 255),
                      Int(b * 255))
    }
}

// MARK: - Team Extension for Theme

extension Team {
    var courtTheme: CourtTheme {
        CourtTheme(from: self)
    }

    /// Set background colors from an array of Colors
    func setBackgroundColors(_ colors: [Color]) {
        let hexStrings = colors.compactMap { $0.toHex() }
        courtBackgroundColor = hexStrings.joined(separator: ",")
    }

    /// Get background colors as an array of Colors
    func getBackgroundColors() -> [Color] {
        guard let colorString = courtBackgroundColor, !colorString.isEmpty else { return [] }
        return colorString
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .compactMap { Color(hex: $0) }
    }

    /// Set line color
    func setLineColor(_ lineColor: CourtLineColor) {
        courtLineColor = lineColor.stringValue
    }

    /// Get line color
    func getLineColor() -> CourtLineColor {
        guard let lineColorString = courtLineColor else { return .white }
        return CourtLineColor(from: lineColorString)
    }

    /// Set pattern
    func setPattern(_ pattern: CourtBackgroundPattern) {
        courtBackgroundPattern = pattern.rawValue
    }

    /// Get pattern
    func getPattern() -> CourtBackgroundPattern {
        guard let patternString = courtBackgroundPattern,
              let pattern = CourtBackgroundPattern(rawValue: patternString) else {
            return .solid
        }
        return pattern
    }
}
