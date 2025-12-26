import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        predicate: NSPredicate(format: "archivedAt == nil"),
        animation: .default)
    private var teams: FetchedResults<Team>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Game.date, ascending: false)],
        predicate: NSPredicate(format: "archivedAt == nil"),
        animation: .default)
    private var games: FetchedResults<Game>

    @State private var showingNewGamePopup = false
    @State private var showingLoadGamePopup = false
    @State private var selectedTeam: Team?
    @State private var navigateToGame = false
    @State private var newGame: Game?
    @State private var showingTeamEditor = false
    @State private var editingTeam: Team?
    @State private var editingTeamFromList = false  // Track if we came from teams list
    @State private var showingTeamsList = false
    @State private var showingPlayersList = false
    @State private var showingSettings = false
    @State private var newGameName = ""

    private static let lastTeamKey = "lastSelectedTeamID"
    private static let lastGameKey = "lastPlayedGameID"

    private var lastPlayedGame: Game? {
        guard let gameIdString = UserDefaults.standard.string(forKey: Self.lastGameKey),
              let gameId = UUID(uuidString: gameIdString) else { return nil }
        return games.first { $0.id == gameId }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let courtAspect: CGFloat = 50.0 / 47.0
                let horizontalPadding: CGFloat = 40  // Space for margins around court
                let courtHeight = max(100, geo.size.height - 16)
                let courtWidth = max(100, courtHeight * courtAspect)
                let sidebarWidth = max(100, geo.size.width - courtWidth - horizontalPadding)

                ZStack {
                    // App background
                    DS.appBackground
                        .ignoresSafeArea()

                    HStack(spacing: 0) {
                        // Left sidebar - menu
                        VStack(spacing: 12) {
                            // App header
                            Image("text-logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .padding(.top, 8)

                            Spacer()

                            // Menu buttons
                            VStack(spacing: 10) {
                                if let game = lastPlayedGame {
                                    Button(action: {
                                        newGame = game
                                        saveLastGame(game)
                                        navigateToGame = true
                                    }) {
                                        HomeMenuButton(
                                            title: "Continue",
                                            icon: "play.fill",
                                            color: .blue
                                        )
                                    }
                                }

                                Button(action: {
                                    loadLastTeam()
                                    showingNewGamePopup = true
                                }) {
                                    HomeMenuButton(
                                        title: "New Game",
                                        icon: "sportscourt",
                                        color: .green
                                    )
                                }

                                Button(action: {
                                    showingLoadGamePopup = true
                                }) {
                                    HomeMenuButton(
                                        title: "Load Game",
                                        icon: "clock.arrow.circlepath",
                                        color: .orange
                                    )
                                }

                                Button(action: {
                                    showingTeamsList = true
                                }) {
                                    HomeMenuButton(
                                        title: "Teams",
                                        icon: "person.3",
                                        color: .blue
                                    )
                                }

                                Button(action: {
                                    showingPlayersList = true
                                }) {
                                    HomeMenuButton(
                                        title: "Players",
                                        icon: "person",
                                        color: .purple
                                    )
                                }

                                Button(action: {
                                    showingSettings = true
                                }) {
                                    HomeMenuButton(
                                        title: "Settings",
                                        icon: "gearshape",
                                        color: .gray
                                    )
                                }
                            }

                            Spacer()
                        }
                        .frame(width: max(sidebarWidth, 200))
                        .padding(12)

                        // Right side - Court preview
                        CourtView(shots: []) { _, _ in }
                            .frame(width: courtWidth, height: courtHeight)
                            .padding(.leading, 8)

                        Spacer()
                            .frame(width: 16)
                    }

                    // Popups
                    if showingNewGamePopup {
                        NewGamePopup(
                            teams: Array(teams),
                            selectedTeam: $selectedTeam,
                            gameName: $newGameName,
                            onStart: { startGame() },
                            onCancel: {
                                showingNewGamePopup = false
                                newGameName = ""
                            },
                            onNewTeam: { createNewTeamFromGame() }
                        )
                    }

                    if showingLoadGamePopup {
                        LoadGamePopup(
                            games: Array(games),
                            teams: Array(teams),
                            onSelect: { game in
                                newGame = game
                                saveLastGame(game)
                                showingLoadGamePopup = false
                                navigateToGame = true
                            },
                            onDelete: { game in
                                deleteGame(game)
                            },
                            onClose: { showingLoadGamePopup = false }
                        )
                    }

                    if showingTeamsList {
                        TeamsListPopup(
                            teams: Array(teams),
                            onEdit: { team in
                                editingTeam = team
                                editingTeamFromList = true
                                showingTeamsList = false
                                showingTeamEditor = true
                            },
                            onNewTeam: {
                                createNewTeam()
                            },
                            onDelete: { team in
                                deleteTeam(team)
                            },
                            onClose: { showingTeamsList = false }
                        )
                    }

                    if showingTeamEditor, let team = editingTeam {
                        TeamEditorPopupWrapper(
                            team: team,
                            onSave: {
                                save()
                                let returnToList = editingTeamFromList
                                showingTeamEditor = false
                                editingTeam = nil
                                editingTeamFromList = false
                                if returnToList {
                                    showingTeamsList = true
                                }
                            },
                            onCancel: {
                                let shouldDelete = team.name?.isEmpty ?? true
                                let returnToList = editingTeamFromList
                                // Hide popup first to prevent re-render with deleted team
                                showingTeamEditor = false
                                editingTeam = nil
                                editingTeamFromList = false
                                if shouldDelete {
                                    viewContext.delete(team)
                                    save()
                                }
                                if returnToList {
                                    showingTeamsList = true
                                }
                            },
                            onOpenSettings: {
                                showingTeamEditor = false
                                editingTeam = nil
                                editingTeamFromList = false
                                showingSettings = true
                            }
                        )
                    }

                    if showingPlayersList {
                        PlayersListPopup(
                            teams: Array(teams),
                            onClose: { showingPlayersList = false }
                        )
                    }

                    if showingSettings {
                        SettingsPopup(onClose: { showingSettings = false })
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToGame) {
                if let game = newGame {
                    GameView(game: game)
                }
            }
        }
    }

    private func loadLastTeam() {
        guard let idString = UserDefaults.standard.string(forKey: Self.lastTeamKey),
              let uuid = UUID(uuidString: idString) else { return }
        selectedTeam = teams.first { $0.id == uuid }
    }

    private func saveLastTeam() {
        if let team = selectedTeam, let id = team.id {
            UserDefaults.standard.set(id.uuidString, forKey: Self.lastTeamKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.lastTeamKey)
        }
    }

    private func saveLastGame(_ game: Game) {
        if let id = game.id {
            UserDefaults.standard.set(id.uuidString, forKey: Self.lastGameKey)
        }
    }

    private func startGame() {
        saveLastTeam()

        let game = Game(context: viewContext)
        game.id = UUID()
        game.date = Date()
        game.name = newGameName.isEmpty ? nil : newGameName
        game.teamId = selectedTeam?.id

        // Update lastSeenAt for all players on this team
        if let teamId = selectedTeam?.id {
            updateLastSeenForTeam(teamId: teamId, date: game.date ?? Date())
        }

        do {
            try viewContext.save()
            newGame = game
            saveLastGame(game)
            showingNewGamePopup = false
            newGameName = ""
            navigateToGame = true
        } catch {
            print("Error creating game: \(error)")
        }
    }

    private func createNewTeamFromGame() {
        let team = Team(context: viewContext)
        team.id = UUID()
        team.name = ""
        team.createdAt = Date()

        // Log team creation
        ActivityLogger.logTeamCreated(context: viewContext, team: team)

        save()
        editingTeam = team
        editingTeamFromList = false
        showingNewGamePopup = false
        showingTeamEditor = true
    }

    private func createNewTeam() {
        let team = Team(context: viewContext)
        team.id = UUID()
        team.name = ""
        team.createdAt = Date()

        // Log team creation
        ActivityLogger.logTeamCreated(context: viewContext, team: team)

        save()
        editingTeam = team
        editingTeamFromList = true
        showingTeamsList = false
        showingTeamEditor = true
    }

    private func deleteTeam(_ team: Team) {
        // Log team archival
        ActivityLogger.logTeamArchived(context: viewContext, team: team)

        team.archivedAt = Date()
        save()
    }

    private func deleteGame(_ game: Game) {
        let teamId = game.teamId
        let archivedGameDate = game.date

        game.archivedAt = Date()
        save()

        // Recalculate lastSeenAt for players on this team
        if let teamId = teamId, let archivedDate = archivedGameDate {
            recalculateLastSeenForTeam(teamId: teamId, afterArchivingGameOn: archivedDate)
        }
    }

    private func updateLastSeenForTeam(teamId: UUID, date: Date) {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "teamId == %@ AND archivedAt == nil", teamId as CVarArg)

        if let players = try? viewContext.fetch(request) {
            for player in players {
                // Only update if this game is more recent
                if player.lastSeenAt == nil || date > player.lastSeenAt! {
                    player.lastSeenAt = date
                }
            }
        }
    }

    private func recalculateLastSeenForTeam(teamId: UUID, afterArchivingGameOn archivedDate: Date) {
        // Find players whose lastSeenAt matches the archived game date
        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        playerRequest.predicate = NSPredicate(format: "teamId == %@ AND archivedAt == nil", teamId as CVarArg)

        guard let players = try? viewContext.fetch(playerRequest) else { return }

        // Find the next most recent game for this team
        let gameRequest: NSFetchRequest<Game> = Game.fetchRequest()
        gameRequest.predicate = NSPredicate(format: "teamId == %@ AND archivedAt == nil", teamId as CVarArg)
        gameRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Game.date, ascending: false)]
        gameRequest.fetchLimit = 1

        let nextMostRecentDate = (try? viewContext.fetch(gameRequest))?.first?.date

        for player in players {
            // If player's lastSeenAt was from the archived game, update it
            if let lastSeen = player.lastSeenAt,
               Calendar.current.isDate(lastSeen, inSameDayAs: archivedDate) {
                player.lastSeenAt = nextMostRecentDate
            }
        }

        save()
    }

    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error)")
        }
    }
}

struct HomeMenuButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(color)
                .cornerRadius(8)

            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
}

struct NewGamePopup: View {
    let teams: [Team]
    @Binding var selectedTeam: Team?
    @Binding var gameName: String
    let onStart: () -> Void
    let onCancel: () -> Void
    let onNewTeam: () -> Void

    @State private var isExpanded = false

    private var selectionText: String {
        if let team = selectedTeam {
            return team.name ?? "Unnamed"
        }
        return "No team"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                Text("New Game")
                    .font(.title.bold())
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Game Name")
                                .font(.headline)
                                .foregroundColor(DS.textPrimary)

                            TextField("e.g. vs Eagles", text: $gameName)
                                .font(.title3)
                                .padding()
                                .background(DS.cardBackground)
                                .cornerRadius(10)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Team")
                                .font(.headline)
                                .foregroundColor(DS.textPrimary)

                            // Dropdown button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Text(selectionText)
                                        .font(.title3)
                                        .foregroundColor(DS.textPrimary)
                                    Spacer()
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.title3)
                                        .foregroundColor(DS.iconChevron)
                                }
                                .padding()
                                .background(DS.cardBackground)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            // Expanded options
                            if isExpanded {
                                VStack(spacing: 4) {
                                    // No team option
                                    Button(action: {
                                        selectedTeam = nil
                                        withAnimation { isExpanded = false }
                                    }) {
                                        HStack {
                                            Text("No team")
                                                .font(.title3)
                                            Spacer()
                                            if selectedTeam == nil {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(DS.actionEdit)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)

                                    // Team list
                                    ForEach(teams) { team in
                                        Button(action: {
                                            selectedTeam = team
                                            withAnimation { isExpanded = false }
                                        }) {
                                            HStack {
                                                Text(team.name ?? "Unnamed")
                                                    .font(.title3)
                                                Spacer()
                                                if selectedTeam == team {
                                                    Image(systemName: "checkmark")
                                                        .foregroundColor(DS.actionEdit)
                                                }
                                            }
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Divider()
                                        .padding(.vertical, 4)

                                    // New team option
                                    Button(action: onNewTeam) {
                                        HStack {
                                            Image(systemName: "plus")
                                                .foregroundColor(DS.actionEdit)
                                            Text("New Team")
                                                .font(.title3)
                                                .foregroundColor(DS.actionEdit)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .background(DS.cardBackground)
                                .cornerRadius(10)
                            }
                        }
                    }
                }

                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.title3)
                    .foregroundColor(DS.actionNeutral)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DS.cardBackground)
                    .cornerRadius(12)

                    Button("Start Game") {
                        onStart()
                    }
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DS.actionPrimary)
                    .cornerRadius(12)
                }
                .padding(.top, 20)
            }
            .padding(28)
            .frame(width: 380)
            .frame(maxHeight: 600)
            .background(DS.popupBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

struct LoadGamePopup: View {
    let games: [Game]
    let teams: [Team]
    let onSelect: (Game) -> Void
    let onDelete: (Game) -> Void
    let onClose: () -> Void

    @State private var selectedTeamFilter: UUID? = nil // nil means "All Teams"
    @State private var gameToDelete: Game? = nil
    @State private var showingDeleteConfirmation = false

    private var teamsWithGames: [Team] {
        let teamIdsWithGames = Set(games.compactMap { $0.teamId })
        return teams.filter { teamIdsWithGames.contains($0.id!) }
    }

    private var filteredGames: [Game] {
        if let teamId = selectedTeamFilter {
            return games.filter { $0.teamId == teamId }
        }
        return games
    }

    private func teamName(for teamId: UUID?) -> String? {
        guard let teamId = teamId else { return nil }
        return teams.first { $0.id == teamId }?.name
    }

    private func gameTitle(_ game: Game) -> String {
        let name = (game.name?.isEmpty == false) ? game.name! : "Game"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: game.date ?? Date())
        return "\(name): \(dateStr)"
    }

    private func gameSubtitle(_ game: Game) -> String {
        if let teamName = teamName(for: game.teamId) {
            return teamName
        }
        return "No team"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 24) {
                HStack {
                    Text("Load Game")
                        .font(.title.bold())
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(DS.iconDismiss)
                    }
                }

                // Team filter (only show if more than one team has games)
                if teamsWithGames.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button(action: { selectedTeamFilter = nil }) {
                                Text("All")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedTeamFilter == nil ? DS.actionEdit : DS.cardBackground)
                                    .foregroundColor(selectedTeamFilter == nil ? .white : DS.textPrimary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(.plain)

                            ForEach(teamsWithGames) { team in
                                Button(action: { selectedTeamFilter = team.id }) {
                                    Text(team.name ?? "Unnamed")
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedTeamFilter == team.id ? DS.actionEdit : DS.cardBackground)
                                        .foregroundColor(selectedTeamFilter == team.id ? .white : DS.textPrimary)
                                        .cornerRadius(20)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if filteredGames.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "sportscourt")
                            .font(.system(size: 40))
                            .foregroundColor(DS.textSecondary)
                        Text(games.isEmpty ? "No saved games" : "No games for this team")
                            .font(.title3)
                            .foregroundColor(DS.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(filteredGames) { game in
                                HStack {
                                    Button(action: { onSelect(game) }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(gameTitle(game))
                                                .font(.title3.bold())
                                                .foregroundColor(DS.textPrimary)
                                            Text(gameSubtitle(game))
                                                .font(.subheadline.bold())
                                                .foregroundColor(DS.gameSubtitle)
                                        }
                                        Spacer()
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: {
                                        gameToDelete = game
                                        showingDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.title3)
                                            .foregroundColor(DS.actionDestructive)
                                    }
                                }
                                .padding()
                                .background(DS.cardBackground)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .frame(maxHeight: 350)
                }

                Button("Cancel") {
                    onClose()
                }
                .font(.title3)
                .foregroundColor(DS.actionNeutral)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DS.cardBackground)
                .cornerRadius(12)
            }
            .padding(28)
            .frame(width: 400)
            .background(DS.popupBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)

            // Delete confirmation popup
            if showingDeleteConfirmation, let game = gameToDelete {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    VStack(spacing: 20) {
                        Text("Delete Game?")
                            .font(.title2.bold())

                        Text("Are you sure you want to delete \"\(game.name?.isEmpty == false ? game.name! : "this game")\"? This cannot be undone.")
                            .font(.body)
                            .foregroundColor(DS.textSecondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Button("Cancel") {
                                gameToDelete = nil
                                showingDeleteConfirmation = false
                            }
                            .font(.title3)
                            .foregroundColor(DS.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(DS.cardBackground)
                            .cornerRadius(10)

                            Button("Delete") {
                                onDelete(game)
                                gameToDelete = nil
                                showingDeleteConfirmation = false
                            }
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                        }
                    }
                    .padding(24)
                    .frame(width: 320)
                    .background(DS.popupBackground)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.3), radius: 15)
                }
            }
        }
    }
}

struct TeamsListPopup: View {
    let teams: [Team]
    let onEdit: (Team) -> Void
    let onNewTeam: () -> Void
    let onDelete: (Team) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 24) {
                HStack {
                    Text("Teams")
                        .font(.title.bold())
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(DS.iconDismiss)
                    }
                }

                if teams.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 40))
                            .foregroundColor(DS.textSecondary)
                        Text("No teams yet")
                            .font(.title3)
                            .foregroundColor(DS.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(teams) { team in
                                TeamRowView(
                                    team: team,
                                    onEdit: { onEdit(team) },
                                    onDelete: { onDelete(team) }
                                )
                                .padding()
                                .background(DS.cardBackground)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }

                Button(action: onNewTeam) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Team")
                    }
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DS.actionEdit)
                    .cornerRadius(12)
                }
            }
            .padding(28)
            .frame(width: 400)
            .background(DS.popupBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

struct PlayersListPopup: View {
    let teams: [Team]
    let onClose: () -> Void

    enum SortColumn: String {
        case number, name, team, lastSeen
    }

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Player.number, ascending: true)],
        predicate: NSPredicate(format: "archivedAt == nil"),
        animation: .default)
    private var allPlayers: FetchedResults<Player>

    enum TeamFilter: Hashable {
        case all
        case unassigned
        case team(UUID)
    }

    private static let sortColumnKey = "PlayersListSortColumn"
    private static let sortAscendingKey = "PlayersListSortAscending"

    @State private var selectedFilter: TeamFilter = .all
    @State private var sortColumn: SortColumn = {
        if let raw = UserDefaults.standard.string(forKey: sortColumnKey),
           let column = SortColumn(rawValue: raw) {
            return column
        }
        return .number
    }()
    @State private var sortAscending: Bool = UserDefaults.standard.object(forKey: sortAscendingKey) as? Bool ?? true
    @State private var isFilterExpanded: Bool = false

    private var hasUnassignedPlayers: Bool {
        allPlayers.contains { $0.teamId == nil }
    }

    private var filteredPlayers: [Player] {
        var players = Array(allPlayers)

        // Filter by selection
        switch selectedFilter {
        case .all:
            break
        case .unassigned:
            players = players.filter { $0.teamId == nil }
        case .team(let teamId):
            players = players.filter { $0.teamId == teamId }
        }

        // Sort
        players.sort { p1, p2 in
            let result: Bool
            switch sortColumn {
            case .number:
                result = p1.number < p2.number
            case .name:
                let name1 = p1.name ?? ""
                let name2 = p2.name ?? ""
                result = name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            case .team:
                let team1 = teamName(for: p1.teamId)
                let team2 = teamName(for: p2.teamId)
                result = team1.localizedCaseInsensitiveCompare(team2) == .orderedAscending
            case .lastSeen:
                let date1 = lastSeenDate(for: p1) ?? Date.distantPast
                let date2 = lastSeenDate(for: p2) ?? Date.distantPast
                result = date1 < date2
            }
            return sortAscending ? result : !result
        }

        return players
    }

    private func teamName(for teamId: UUID?) -> String {
        guard let teamId = teamId else { return "No Team" }
        if let team = teams.first(where: { $0.id == teamId }) {
            return team.name ?? "Unnamed"
        }
        return "(Archived Team)"
    }

    private func lastSeenDate(for player: Player) -> Date? {
        return player.lastSeenAt
    }

    private var filterDisplayText: String {
        switch selectedFilter {
        case .all:
            return "All Teams"
        case .unassigned:
            return "Unassigned Players"
        case .team(let teamId):
            return teams.first(where: { $0.id == teamId })?.name ?? "Unknown Team"
        }
    }

    private func sortIndicator(for column: SortColumn) -> String {
        if sortColumn == column {
            return sortAscending ? "chevron.up" : "chevron.down"
        }
        return ""
    }

    private func toggleSort(for column: SortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        // Save preferences
        UserDefaults.standard.set(sortColumn.rawValue, forKey: Self.sortColumnKey)
        UserDefaults.standard.set(sortAscending, forKey: Self.sortAscendingKey)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Players")
                        .font(.title.bold())
                    Spacer()
                    Text("\(filteredPlayers.count) total")
                        .font(.subheadline)
                        .foregroundColor(DS.textSecondary)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(DS.iconDismiss)
                    }
                }

                // Filter dropdown
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFilterExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text(filterDisplayText)
                                .font(.subheadline.bold())
                            Spacer()
                            Image(systemName: isFilterExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .foregroundColor(DS.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DS.cardBackground)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 200)

                    if isFilterExpanded {
                        VStack(alignment: .leading, spacing: 0) {
                            // All Teams
                            Button(action: {
                                selectedFilter = .all
                                withAnimation { isFilterExpanded = false }
                            }) {
                                HStack {
                                    Text("All Teams")
                                        .font(.subheadline)
                                    Spacer()
                                    if case .all = selectedFilter {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundColor(DS.actionEdit)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            // Unassigned Players (only if there are any)
                            if hasUnassignedPlayers {
                                Button(action: {
                                    selectedFilter = .unassigned
                                    withAnimation { isFilterExpanded = false }
                                }) {
                                    HStack {
                                        Text("Unassigned Players")
                                            .font(.subheadline)
                                        Spacer()
                                        if case .unassigned = selectedFilter {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundColor(DS.actionEdit)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }

                            // Divider if we have teams
                            if !teams.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                            }

                            // Teams in alphabetical order
                            ForEach(teams) { team in
                                Button(action: {
                                    selectedFilter = .team(team.id!)
                                    withAnimation { isFilterExpanded = false }
                                }) {
                                    HStack {
                                        Text(team.name ?? "Unnamed")
                                            .font(.subheadline)
                                        Spacer()
                                        if case .team(let id) = selectedFilter, id == team.id {
                                            Image(systemName: "checkmark")
                                                .font(.caption)
                                                .foregroundColor(DS.actionEdit)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(DS.cardBackground)
                        .cornerRadius(8)
                        .frame(width: 200)
                    }
                }

                // Column headers
                HStack(spacing: 0) {
                    Button(action: { toggleSort(for: .number) }) {
                        HStack(spacing: 4) {
                            Text("#")
                            if !sortIndicator(for: .number).isEmpty {
                                Image(systemName: sortIndicator(for: .number))
                                    .font(.caption2)
                            }
                        }
                        .font(.caption.bold())
                        .foregroundColor(sortColumn == .number ? DS.actionEdit : DS.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 50, alignment: .leading)

                    Button(action: { toggleSort(for: .name) }) {
                        HStack(spacing: 4) {
                            Text("Name")
                            if !sortIndicator(for: .name).isEmpty {
                                Image(systemName: sortIndicator(for: .name))
                                    .font(.caption2)
                            }
                        }
                        .font(.caption.bold())
                        .foregroundColor(sortColumn == .name ? DS.actionEdit : DS.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 140, alignment: .leading)

                    Button(action: { toggleSort(for: .team) }) {
                        HStack(spacing: 4) {
                            Text("Team")
                            if !sortIndicator(for: .team).isEmpty {
                                Image(systemName: sortIndicator(for: .team))
                                    .font(.caption2)
                            }
                        }
                        .font(.caption.bold())
                        .foregroundColor(sortColumn == .team ? DS.actionEdit : DS.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 120, alignment: .leading)

                    Button(action: { toggleSort(for: .lastSeen) }) {
                        HStack(spacing: 4) {
                            Text("Last Seen")
                            if !sortIndicator(for: .lastSeen).isEmpty {
                                Image(systemName: sortIndicator(for: .lastSeen))
                                    .font(.caption2)
                            }
                        }
                        .font(.caption.bold())
                        .foregroundColor(sortColumn == .lastSeen ? DS.actionEdit : DS.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 90, alignment: .leading)

                    Spacer()
                    Text("ID")
                        .font(.caption.bold())
                        .foregroundColor(DS.textSecondary)
                }
                .padding(.horizontal, 12)

                if filteredPlayers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person")
                            .font(.system(size: 40))
                            .foregroundColor(DS.textSecondary)
                        Text("No players")
                            .font(.title3)
                            .foregroundColor(DS.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(filteredPlayers, id: \.id) { player in
                                HStack(spacing: 0) {
                                    Text("#\(player.number)")
                                        .font(.subheadline.bold())
                                        .frame(width: 50, alignment: .leading)

                                    Text(player.name ?? "(no name)")
                                        .font(.subheadline)
                                        .foregroundColor(player.name != nil ? DS.textPrimary : DS.textSecondary)
                                        .frame(width: 140, alignment: .leading)
                                        .lineLimit(1)

                                    Text(teamName(for: player.teamId))
                                        .font(.subheadline)
                                        .foregroundColor(player.teamId != nil ? DS.textPrimary : DS.textSecondary)
                                        .frame(width: 120, alignment: .leading)
                                        .lineLimit(1)

                                    Text(formatDate(lastSeenDate(for: player)))
                                        .font(.subheadline)
                                        .foregroundColor(DS.textSecondary)
                                        .frame(width: 90, alignment: .leading)

                                    Spacer()

                                    if let id = player.id {
                                        Text(id.uuidString.prefix(8) + "...")
                                            .font(.caption2)
                                            .foregroundColor(DS.textSecondary.opacity(0.5))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(DS.cardBackground)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(maxHeight: 350)
                }

                Button("Close") {
                    onClose()
                }
                .font(.title3)
                .foregroundColor(DS.actionNeutral)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DS.cardBackground)
                .cornerRadius(12)
            }
            .padding(24)
            .frame(width: 600)
            .background(DS.popupBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

struct TeamRowView: View {
    let team: Team
    let onEdit: () -> Void
    let onDelete: () -> Void

    @FetchRequest private var players: FetchedResults<Player>

    init(team: Team, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.team = team
        self.onEdit = onEdit
        self.onDelete = onDelete

        let predicate = NSPredicate(format: "teamId == %@ AND archivedAt == nil", team.id! as CVarArg)
        _players = FetchRequest(
            sortDescriptors: [],
            predicate: predicate
        )
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(team.name ?? "Unnamed")
                    .font(.title3.bold())
                Text("\(players.count) player\(players.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(DS.playerInfo)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundColor(DS.actionEdit)
            }
            .padding(.horizontal, 8)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundColor(DS.actionDestructive)
            }
        }
    }
}

struct TeamEditorPopupWrapper: View {
    let team: Team
    let onSave: () -> Void
    let onCancel: () -> Void
    var onOpenSettings: (() -> Void)? = nil

    @FetchRequest private var players: FetchedResults<Player>

    init(team: Team, onSave: @escaping () -> Void, onCancel: @escaping () -> Void, onOpenSettings: (() -> Void)? = nil) {
        self.team = team
        self.onSave = onSave
        self.onCancel = onCancel
        self.onOpenSettings = onOpenSettings

        let predicate: NSPredicate
        if let teamId = team.id {
            predicate = NSPredicate(format: "teamId == %@ AND archivedAt == nil", teamId as CVarArg)
        } else {
            // Team has no ID yet (shouldn't happen, but be safe)
            predicate = NSPredicate(value: false)
        }
        _players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.number, ascending: true)],
            predicate: predicate
        )
    }

    var body: some View {
        TeamEditorPopup(
            team: team,
            players: Array(players),
            onSave: onSave,
            onCancel: onCancel,
            onOpenSettings: onOpenSettings
        )
    }
}

struct TeamEditorPopup: View {
    @ObservedObject var team: Team
    let players: [Player]
    let onSave: () -> Void
    let onCancel: () -> Void
    var onOpenSettings: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Player.name, ascending: true)],
        predicate: NSPredicate(format: "archivedAt == nil"),
        animation: .default)
    private var allPlayers: FetchedResults<Player>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        predicate: NSPredicate(format: "archivedAt == nil"),
        animation: .default)
    private var allTeams: FetchedResults<Team>

    @State private var teamName: String = ""
    @State private var newPlayerNumber: String = ""
    @State private var newPlayerName: String = ""
    @FocusState private var numberFieldFocused: Bool
    @State private var showingDiscardAlert = false
    @State private var showDuplicateWarning = false
    @State private var showingPlayerMatch = false
    @State private var matchedPlayer: Player? = nil
    @State private var recentlyAddedPlayerId: UUID? = nil
    @State private var showingHistory = false

    // Track original values to detect changes
    @State private var originalName: String = ""
    @State private var originalCourtType: String? = nil
    @State private var originalPlayerCount: Int = 0

    private var hasChanges: Bool {
        teamName != originalName ||
        team.courtType != originalCourtType ||
        players.count != originalPlayerCount ||
        !newPlayerNumber.isEmpty
    }

    private var isDuplicateNumber: Bool {
        guard let number = Int16(newPlayerNumber) else { return false }
        return players.contains { $0.number == number }
    }

    // Check if name already exists on THIS team
    private var isDuplicateNameOnTeam: Bool {
        guard !newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let trimmedName = newPlayerName.trimmingCharacters(in: .whitespaces).lowercased()
        return players.contains { ($0.name ?? "").lowercased() == trimmedName }
    }

    // Find matching player on OTHER teams
    private var matchingPlayerOnOtherTeam: Player? {
        guard !newPlayerName.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let trimmedName = newPlayerName.trimmingCharacters(in: .whitespaces).lowercased()
        return allPlayers.first { player in
            player.teamId != team.id &&
            (player.name ?? "").lowercased() == trimmedName
        }
    }

    private func teamName(for teamId: UUID?) -> String {
        guard let teamId = teamId else { return "No Team" }
        return allTeams.first { $0.id == teamId }?.name ?? "Unknown Team"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with Cancel/Save
                HStack {
                    Button("Cancel") {
                        if hasChanges {
                            showingDiscardAlert = true
                        } else {
                            onCancel()
                        }
                    }
                    .font(.body)
                    .foregroundColor(DS.actionNeutral)

                    Spacer()

                    Text(team.name?.isEmpty ?? true ? "New Team" : "Edit Team")
                        .font(.headline)

                    Spacer()

                    Button("Save") {
                        if teamName.isEmpty {
                            team.name = "Unnamed"
                        }
                        if !newPlayerNumber.isEmpty {
                            addPlayer()
                        }

                        // Log team name change if name was modified
                        let finalName = team.name ?? ""
                        if !originalName.isEmpty && originalName != finalName {
                            ActivityLogger.logTeamNameChanged(
                                context: viewContext,
                                team: team,
                                oldName: originalName,
                                newName: finalName
                            )
                        }

                        onSave()
                    }
                    .font(.headline)
                    .foregroundColor(DS.actionEdit)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(DS.popupBackground)

                Divider()

                ScrollView {
                VStack(spacing: 24) {

                // Team name
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Team Name")
                            .font(.headline)
                            .foregroundColor(DS.textPrimary)
                        Spacer()
                        Button(action: { showingHistory = true }) {
                            Label("History", systemImage: "clock.arrow.circlepath")
                                .font(.subheadline)
                                .foregroundColor(DS.actionEdit)
                        }
                    }
                    TextField("Enter team name", text: $teamName)
                        .font(.title3)
                        .padding()
                        .background(DS.cardBackground)
                        .cornerRadius(10)
                        .onAppear { teamName = team.name ?? "" }
                        .onChange(of: teamName) { _, newValue in
                            team.name = newValue
                        }
                }

                // Players
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(players.count) Player\(players.count == 1 ? "" : "s")")
                            .font(.headline)
                            .foregroundColor(DS.textPrimary)

                        if showDuplicateWarning {
                            if isDuplicateNumber {
                                Text("— #\(newPlayerNumber) already exists")
                                    .font(.subheadline)
                                    .foregroundColor(DS.actionDestructive)
                            } else if isDuplicateNameOnTeam {
                                Text("— \"\(newPlayerName)\" already on team")
                                    .font(.subheadline)
                                    .foregroundColor(DS.actionDestructive)
                            }
                        }
                    }

                    // Add player - at top so keyboard doesn't cover it
                    HStack(spacing: 12) {
                        TextField("#", text: $newPlayerNumber)
                            .font(.title3)
                            .keyboardType(.numberPad)
                            .padding()
                            .background(DS.cardBackground)
                            .cornerRadius(10)
                            .frame(width: 70)
                            .focused($numberFieldFocused)
                            .onChange(of: newPlayerNumber) { _, _ in
                                checkForDuplicates()
                            }

                        TextField("Name (optional)", text: $newPlayerName)
                            .font(.title3)
                            .padding()
                            .background(DS.cardBackground)
                            .cornerRadius(10)
                            .onChange(of: newPlayerName) { _, _ in
                                checkForDuplicates()
                            }

                        Button(action: handleAddPlayer) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(newPlayerNumber.isEmpty ? DS.textSecondary : (isDuplicateNumber || isDuplicateNameOnTeam ? DS.actionDestructive : DS.actionEdit))
                        }
                        .disabled(newPlayerNumber.isEmpty || isDuplicateNumber || isDuplicateNameOnTeam)
                    }

                    // Show matching player on other team
                    if let match = matchingPlayerOnOtherTeam, !isDuplicateNameOnTeam {
                        HStack {
                            Image(systemName: "person.fill.questionmark")
                                .foregroundColor(.orange)
                            Text("Found \"\(match.name ?? "")\" on \(teamName(for: match.teamId))")
                                .font(.subheadline)
                                .foregroundColor(DS.textSecondary)
                            Spacer()
                            Button("Transfer") {
                                transferPlayer(match)
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(DS.actionEdit)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(players, id: \.id) { player in
                                    HStack {
                                        Text("#\(player.number)")
                                            .font(.title3.bold())
                                            .frame(width: 60, alignment: .leading)

                                        if let name = player.name, !name.isEmpty {
                                            Text(name)
                                                .font(.title3)
                                                .foregroundColor(DS.textSecondary)
                                        }

                                        Spacer()

                                        Button(action: { deletePlayer(player) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(DS.actionDestructive)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        recentlyAddedPlayerId == player.id
                                            ? Color.green.opacity(0.3)
                                            : DS.cardBackground
                                    )
                                    .cornerRadius(8)
                                    .id(player.id)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                        .onChange(of: recentlyAddedPlayerId) { _, newId in
                            if let id = newId {
                                withAnimation {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                                // Fade out highlight after delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        recentlyAddedPlayerId = nil
                                    }
                                }
                            }
                        }
                    }
                }

                // Court Type
                VStack(alignment: .leading, spacing: 8) {
                    Text("Court Type")
                        .font(.headline)
                        .foregroundColor(DS.textPrimary)

                    HStack(spacing: 8) {
                        // Use Default option
                        Button(action: { team.courtType = nil }) {
                            Text("Use Default")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(team.courtType == nil ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(team.courtType == nil ? .white : DS.textPrimary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        ForEach(CourtType.allCases, id: \.rawValue) { type in
                            Button(action: { team.courtType = type.rawValue }) {
                                Text(type.displayName)
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(team.courtType == type.rawValue ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(team.courtType == type.rawValue ? .white : DS.textPrimary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Court Theme
                CourtThemeEditorView(team: team, onOpenSettings: onOpenSettings)
                }
                .padding(24)
                }
            }
            .frame(width: 450)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
            .fixedSize(horizontal: false, vertical: true)
            .background(DS.popupBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
        .onAppear {
            originalName = team.name ?? ""
            originalCourtType = team.courtType
            originalPlayerCount = players.count
        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard", role: .destructive) {
                onCancel()
            }
        } message: {
            Text("You have unsaved changes that will be lost.")
        }
        .sheet(isPresented: $showingHistory) {
            if let teamId = team.id {
                ActivityHistoryView(subjectId: teamId, subjectType: "team", title: team.name ?? "Team")
            }
        }
    }

    private func checkForDuplicates() {
        showDuplicateWarning = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if isDuplicateNumber || isDuplicateNameOnTeam {
                showDuplicateWarning = true
            }
        }
    }

    private func handleAddPlayer() {
        // If there's a matching player on another team, show transfer option
        // But for now, just add the new player
        addPlayer()
    }

    private func addPlayer() {
        guard let number = Int16(newPlayerNumber) else { return }

        // Check if number already exists
        if players.contains(where: { $0.number == number }) {
            return
        }

        // Check if name already exists on team
        if isDuplicateNameOnTeam {
            return
        }

        let player = Player(context: viewContext)
        player.id = UUID()
        player.number = number
        player.name = newPlayerName.isEmpty ? nil : newPlayerName
        player.teamId = team.id
        player.createdAt = Date()

        // Log player creation
        ActivityLogger.logPlayerCreated(
            context: viewContext,
            player: player,
            teamName: team.name
        )

        let addedId = player.id
        newPlayerNumber = ""
        newPlayerName = ""
        showDuplicateWarning = false
        numberFieldFocused = true

        // Scroll to and highlight the new player after list updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            recentlyAddedPlayerId = addedId
        }
    }

    private func transferPlayer(_ player: Player) {
        guard let number = Int16(newPlayerNumber), !newPlayerNumber.isEmpty else { return }

        // Check if number already exists on this team
        if players.contains(where: { $0.number == number }) {
            showDuplicateWarning = true
            return
        }

        let oldTeamId = player.teamId
        let oldTeamName = teamName(for: oldTeamId)
        let oldNumber = player.number

        // Log leaving old team (if any)
        if let oldId = oldTeamId {
            ActivityLogger.logPlayerLeftTeam(
                context: viewContext,
                player: player,
                teamId: oldId,
                teamName: oldTeamName
            )
        }

        // Transfer player to this team with new number
        player.teamId = team.id
        player.number = number

        // Log joining new team
        if let newTeamId = team.id {
            ActivityLogger.logPlayerJoinedTeam(
                context: viewContext,
                player: player,
                teamId: newTeamId,
                teamName: team.name ?? "Unnamed"
            )
        }

        // Log jersey change if number changed
        if oldNumber != number {
            ActivityLogger.logPlayerJerseyChanged(
                context: viewContext,
                player: player,
                oldNumber: oldNumber,
                newNumber: number
            )
        }

        let transferredId = player.id
        newPlayerNumber = ""
        newPlayerName = ""
        showDuplicateWarning = false
        numberFieldFocused = true

        // Scroll to and highlight the transferred player after list updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            recentlyAddedPlayerId = transferredId
        }
    }

    private func deletePlayer(_ player: Player) {
        // Log player archived
        ActivityLogger.logPlayerArchived(
            context: viewContext,
            player: player,
            teamName: teamName(for: player.teamId)
        )

        player.archivedAt = Date()
    }
}

struct ActivityHistoryView: View {
    let subjectId: UUID
    let subjectType: String
    let title: String

    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var activities: FetchedResults<ActivityLog>

    init(subjectId: UUID, subjectType: String, title: String) {
        self.subjectId = subjectId
        self.subjectType = subjectType
        self.title = title

        _activities = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ActivityLog.timestamp, ascending: false)],
            predicate: NSPredicate(format: "subjectId == %@", subjectId as CVarArg)
        )
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func iconForActivityType(_ type: String?) -> String {
        switch type {
        case "player_created", "team_created": return "plus.circle.fill"
        case "player_archived", "team_archived": return "archivebox.fill"
        case "player_joined_team", "team_player_joined": return "person.badge.plus"
        case "player_left_team", "team_player_left": return "person.badge.minus"
        case "player_jersey_changed": return "tshirt.fill"
        case "player_name_changed", "team_name_changed": return "pencil"
        default: return "clock"
        }
    }

    private func colorForActivityType(_ type: String?) -> Color {
        switch type {
        case "player_created", "team_created": return .green
        case "player_archived", "team_archived": return .red
        case "player_joined_team", "team_player_joined": return .blue
        case "player_left_team", "team_player_left": return .orange
        case "player_jersey_changed": return .purple
        case "player_name_changed", "team_name_changed": return .teal
        default: return .gray
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(DS.textSecondary)
                        Text("No history yet")
                            .font(.title3)
                            .foregroundColor(DS.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(activities, id: \.id) { activity in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: iconForActivityType(activity.activityType))
                                    .font(.title3)
                                    .foregroundColor(colorForActivityType(activity.activityType))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(activity.descriptionText ?? "Unknown activity")
                                        .font(.body)
                                        .foregroundColor(DS.textPrimary)

                                    Text(formatDate(activity.timestamp))
                                        .font(.caption)
                                        .foregroundColor(DS.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(title) History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
