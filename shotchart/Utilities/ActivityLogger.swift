import Foundation
import CoreData

/// Helper for logging activities to the ActivityLog entity
enum ActivityLogger {

    // MARK: - Subject Types

    enum SubjectType: String {
        case player
        case team
    }

    // MARK: - Activity Types

    enum ActivityType: String {
        // Player activities
        case playerCreated = "player_created"
        case playerArchived = "player_archived"
        case playerJoinedTeam = "player_joined_team"
        case playerLeftTeam = "player_left_team"
        case playerJerseyChanged = "player_jersey_changed"
        case playerNameChanged = "player_name_changed"

        // Team activities
        case teamCreated = "team_created"
        case teamArchived = "team_archived"
        case teamNameChanged = "team_name_changed"
        case teamPlayerJoined = "team_player_joined"
        case teamPlayerLeft = "team_player_left"
    }

    // MARK: - Core Logging Function

    /// Log an activity to the ActivityLog
    static func log(
        context: NSManagedObjectContext,
        subjectId: UUID,
        subjectType: SubjectType,
        activityType: ActivityType,
        description: String,
        relatedId: UUID? = nil
    ) {
        let entry = ActivityLog(context: context)
        entry.id = UUID()
        entry.subjectId = subjectId
        entry.subjectType = subjectType.rawValue
        entry.activityType = activityType.rawValue
        entry.descriptionText = description
        entry.relatedId = relatedId
        entry.timestamp = Date()
    }

    // MARK: - Player Activity Helpers

    /// Log player creation
    static func logPlayerCreated(
        context: NSManagedObjectContext,
        player: Player,
        teamName: String?
    ) {
        guard let playerId = player.id else { return }

        let playerDesc = playerDescription(player)
        let desc = teamName != nil
            ? "Created and joined \(teamName!)"
            : "Created (no team)"

        log(
            context: context,
            subjectId: playerId,
            subjectType: .player,
            activityType: .playerCreated,
            description: desc,
            relatedId: player.teamId
        )

        // Also log from team's perspective if there's a team
        if let teamId = player.teamId {
            log(
                context: context,
                subjectId: teamId,
                subjectType: .team,
                activityType: .teamPlayerJoined,
                description: "\(playerDesc) joined",
                relatedId: playerId
            )
        }
    }

    /// Log player archived
    static func logPlayerArchived(
        context: NSManagedObjectContext,
        player: Player,
        teamName: String?
    ) {
        guard let playerId = player.id else { return }

        let playerDesc = playerDescription(player)
        let desc = teamName != nil
            ? "Archived from \(teamName!)"
            : "Archived"

        log(
            context: context,
            subjectId: playerId,
            subjectType: .player,
            activityType: .playerArchived,
            description: desc,
            relatedId: player.teamId
        )

        // Also log from team's perspective if there's a team
        if let teamId = player.teamId {
            log(
                context: context,
                subjectId: teamId,
                subjectType: .team,
                activityType: .teamPlayerLeft,
                description: "\(playerDesc) archived",
                relatedId: playerId
            )
        }
    }

    /// Log player joining a team
    static func logPlayerJoinedTeam(
        context: NSManagedObjectContext,
        player: Player,
        teamId: UUID,
        teamName: String
    ) {
        guard let playerId = player.id else { return }

        let playerDesc = playerDescription(player)

        // From player's perspective
        log(
            context: context,
            subjectId: playerId,
            subjectType: .player,
            activityType: .playerJoinedTeam,
            description: "Joined \(teamName)",
            relatedId: teamId
        )

        // From team's perspective
        log(
            context: context,
            subjectId: teamId,
            subjectType: .team,
            activityType: .teamPlayerJoined,
            description: "\(playerDesc) joined",
            relatedId: playerId
        )
    }

    /// Log player leaving a team
    static func logPlayerLeftTeam(
        context: NSManagedObjectContext,
        player: Player,
        teamId: UUID,
        teamName: String
    ) {
        guard let playerId = player.id else { return }

        let playerDesc = playerDescription(player)

        // From player's perspective
        log(
            context: context,
            subjectId: playerId,
            subjectType: .player,
            activityType: .playerLeftTeam,
            description: "Left \(teamName)",
            relatedId: teamId
        )

        // From team's perspective
        log(
            context: context,
            subjectId: teamId,
            subjectType: .team,
            activityType: .teamPlayerLeft,
            description: "\(playerDesc) left",
            relatedId: playerId
        )
    }

    /// Log player jersey number change
    static func logPlayerJerseyChanged(
        context: NSManagedObjectContext,
        player: Player,
        oldNumber: Int16,
        newNumber: Int16
    ) {
        guard let playerId = player.id else { return }

        log(
            context: context,
            subjectId: playerId,
            subjectType: .player,
            activityType: .playerJerseyChanged,
            description: "Changed jersey #\(oldNumber) → #\(newNumber)",
            relatedId: player.teamId
        )
    }

    /// Log player name change
    static func logPlayerNameChanged(
        context: NSManagedObjectContext,
        player: Player,
        oldName: String?,
        newName: String?
    ) {
        guard let playerId = player.id else { return }

        let oldDisplay = oldName?.isEmpty == false ? oldName! : "(no name)"
        let newDisplay = newName?.isEmpty == false ? newName! : "(no name)"

        log(
            context: context,
            subjectId: playerId,
            subjectType: .player,
            activityType: .playerNameChanged,
            description: "Changed name \"\(oldDisplay)\" → \"\(newDisplay)\"",
            relatedId: player.teamId
        )
    }

    // MARK: - Team Activity Helpers

    /// Log team creation
    static func logTeamCreated(
        context: NSManagedObjectContext,
        team: Team
    ) {
        guard let teamId = team.id else { return }

        log(
            context: context,
            subjectId: teamId,
            subjectType: .team,
            activityType: .teamCreated,
            description: "Created"
        )
    }

    /// Log team archived
    static func logTeamArchived(
        context: NSManagedObjectContext,
        team: Team
    ) {
        guard let teamId = team.id else { return }

        log(
            context: context,
            subjectId: teamId,
            subjectType: .team,
            activityType: .teamArchived,
            description: "Archived"
        )
    }

    /// Log team name change
    static func logTeamNameChanged(
        context: NSManagedObjectContext,
        team: Team,
        oldName: String?,
        newName: String?
    ) {
        guard let teamId = team.id else { return }

        let oldDisplay = oldName?.isEmpty == false ? oldName! : "(unnamed)"
        let newDisplay = newName?.isEmpty == false ? newName! : "(unnamed)"

        log(
            context: context,
            subjectId: teamId,
            subjectType: .team,
            activityType: .teamNameChanged,
            description: "Renamed \"\(oldDisplay)\" → \"\(newDisplay)\""
        )
    }

    // MARK: - Helpers

    /// Get a description string for a player (e.g., "John (#5)" or "#5")
    private static func playerDescription(_ player: Player) -> String {
        if let name = player.name, !name.isEmpty {
            return "\(name) (#\(player.number))"
        } else {
            return "#\(player.number)"
        }
    }
}
