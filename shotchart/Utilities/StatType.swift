import Foundation

enum StatType: String, CaseIterable {
    case layup = "LA"
    case steal = "STL"
    case turnover = "TO"
    case assist = "AST"
    case offensiveRebound = "ORB"
    case defensiveRebound = "DRB"
    case offensiveFoul = "OF"
    case defensiveFoul = "DF"

    var fullName: String {
        switch self {
        case .layup: return "Layup"
        case .steal: return "Steal"
        case .turnover: return "Turnover"
        case .assist: return "Assist"
        case .offensiveRebound: return "Offensive Rebound"
        case .defensiveRebound: return "Defensive Rebound"
        case .offensiveFoul: return "Offensive Foul"
        case .defensiveFoul: return "Defensive Foul"
        }
    }

    var abbreviation: String { rawValue }

    func displayName(useAbbreviation: Bool) -> String {
        useAbbreviation ? abbreviation : fullName
    }

    /// AppStorage key for visibility setting
    var storageKey: String {
        switch self {
        case .layup: return "showLayup"
        case .steal: return "showSteal"
        case .turnover: return "showTurnover"
        case .assist: return "showAssist"
        case .offensiveRebound: return "showOffensiveRebound"
        case .defensiveRebound: return "showDefensiveRebound"
        case .offensiveFoul: return "showOffensiveFoul"
        case .defensiveFoul: return "showDefensiveFoul"
        }
    }
}
