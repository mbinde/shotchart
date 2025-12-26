import SwiftUI

// MARK: - Design System
// Centralized colors and styling for the app
// Adjust these values to tweak the entire app's appearance

struct DS {
    // MARK: - Text Colors

    /// Primary text - highest contrast, for titles and important content
    static let textPrimary = Color.primary

    /// Secondary text - for subtitles, metadata, supporting info
    /// Using a darker color than .secondary for better contrast
    static let textSecondary = Color(uiColor: .darkGray)

    /// Accent text - for clickable/tappable items, team names, links
    static let textAccent = Color(red: 0.0, green: 0.4, blue: 0.8) // Darker blue

    // MARK: - Background Colors

    /// Main app background - dark blue
    static let appBackground = Color(red: 4/255, green: 32/255, blue: 72/255)

    /// Card/row background - for list items, buttons
    static let cardBackground = Color(uiColor: .secondarySystemBackground)

    /// Selected/highlighted card background
    static let cardBackgroundSelected = Color.blue.opacity(0.15)

    /// Popup/modal background
    static let popupBackground = Color(uiColor: .systemBackground)

    // MARK: - Action Colors

    /// Primary action (Start Game, Save, etc.)
    static let actionPrimary = Color.green

    /// Destructive action (Delete, Cancel)
    static let actionDestructive = Color.red

    /// Edit/modify action
    static let actionEdit = Color(red: 0.0, green: 0.4, blue: 0.8) // Darker blue

    /// Neutral action (Cancel buttons)
    static let actionNeutral = Color(uiColor: .darkGray)

    // MARK: - Status Colors

    /// Success/made shot
    static let statusSuccess = Color.green

    /// Failure/missed shot
    static let statusFailure = Color.red

    /// Warning/caution
    static let statusWarning = Color.orange

    // MARK: - Icon Colors

    /// Chevron and navigation icons
    static let iconChevron = Color(red: 0.0, green: 0.4, blue: 0.8)

    /// Close/dismiss icons
    static let iconDismiss = Color(uiColor: .darkGray)

    // MARK: - Specific UI Elements

    /// Team name display color
    static let teamName = Color(red: 0.0, green: 0.4, blue: 0.8)

    /// Player count/info color
    static let playerInfo = Color(red: 0.0, green: 0.4, blue: 0.8)

    /// Game subtitle (team name in game list)
    static let gameSubtitle = Color(red: 0.0, green: 0.4, blue: 0.8)
}
