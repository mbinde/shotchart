import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        animation: .default)
    private var teams: FetchedResults<Team>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Game.date, ascending: false)],
        animation: .default)
    private var games: FetchedResults<Game>

    @State private var showingNewGamePopup = false
    @State private var showingLoadGamePopup = false
    @State private var selectedTeam: Team?
    @State private var navigateToGame = false
    @State private var newGame: Game?
    @State private var showingTeamEditor = false
    @State private var editingTeam: Team?
    @State private var showingTeamsList = false
    @State private var showingSettings = false

    private static let lastTeamKey = "lastSelectedTeamID"

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
                        VStack(spacing: 24) {
                            // App header
                            Image("text-logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 160)
                                .padding(.top, 20)

                            Spacer()

                            // Menu buttons
                            VStack(spacing: 16) {
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
                            onStart: { startGame() },
                            onCancel: { showingNewGamePopup = false },
                            onNewTeam: { createNewTeamFromGame() }
                        )
                    }

                    if showingLoadGamePopup {
                        LoadGamePopup(
                            games: Array(games),
                            teams: Array(teams),
                            onSelect: { game in
                                newGame = game
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
                                showingTeamEditor = false
                                editingTeam = nil
                            },
                            onCancel: {
                                if team.name?.isEmpty ?? true {
                                    viewContext.delete(team)
                                    save()
                                }
                                showingTeamEditor = false
                                editingTeam = nil
                            }
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

    private func startGame() {
        saveLastTeam()

        let game = Game(context: viewContext)
        game.id = UUID()
        game.date = Date()
        game.teamId = selectedTeam?.id

        do {
            try viewContext.save()
            newGame = game
            showingNewGamePopup = false
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
        save()
        editingTeam = team
        showingNewGamePopup = false
        showingTeamEditor = true
    }

    private func createNewTeam() {
        let team = Team(context: viewContext)
        team.id = UUID()
        team.name = ""
        team.createdAt = Date()
        save()
        editingTeam = team
        showingTeamsList = false
        showingTeamEditor = true
    }

    private func deleteTeam(_ team: Team) {
        viewContext.delete(team)
        save()
    }

    private func deleteGame(_ game: Game) {
        viewContext.delete(game)
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
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(color)
                .cornerRadius(12)

            Text(title)
                .font(.title3.bold())
                .foregroundColor(.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
    }
}

struct NewGamePopup: View {
    let teams: [Team]
    @Binding var selectedTeam: Team?
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

            VStack(spacing: 24) {
                Text("New Game")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 12) {
                    Text("Team")
                        .font(.headline)
                        .foregroundColor(DS.textPrimary)

                    // Dropdown button
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
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
            }
            .padding(28)
            .frame(width: 350)
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

                                    Button(action: { onDelete(game) }) {
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

struct TeamRowView: View {
    let team: Team
    let onEdit: () -> Void
    let onDelete: () -> Void

    @FetchRequest private var players: FetchedResults<Player>

    init(team: Team, onEdit: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.team = team
        self.onEdit = onEdit
        self.onDelete = onDelete

        let predicate = NSPredicate(format: "teamId == %@", team.id! as CVarArg)
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

    @FetchRequest private var players: FetchedResults<Player>

    init(team: Team, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.team = team
        self.onSave = onSave
        self.onCancel = onCancel

        let predicate = NSPredicate(format: "teamId == %@", team.id! as CVarArg)
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
            onCancel: onCancel
        )
    }
}

struct TeamEditorPopup: View {
    @ObservedObject var team: Team
    let players: [Player]
    let onSave: () -> Void
    let onCancel: () -> Void

    @Environment(\.managedObjectContext) private var viewContext
    @State private var teamName: String = ""
    @State private var newPlayerNumber: String = ""
    @State private var newPlayerName: String = ""
    @FocusState private var numberFieldFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack {
                VStack(spacing: 24) {
                    Text(team.name?.isEmpty ?? true ? "New Team" : "Edit Team")
                        .font(.title.bold())

                // Team name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Team Name")
                        .font(.headline)
                        .foregroundColor(DS.textPrimary)
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
                    Text("Players")
                        .font(.headline)
                        .foregroundColor(DS.textPrimary)

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

                        TextField("Name (optional)", text: $newPlayerName)
                            .font(.title3)
                            .padding()
                            .background(DS.cardBackground)
                            .cornerRadius(10)

                        Button(action: addPlayer) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundColor(newPlayerNumber.isEmpty ? DS.textSecondary : DS.actionEdit)
                        }
                        .disabled(newPlayerNumber.isEmpty)
                    }

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
                                .background(DS.cardBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
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

                    Button("Save") {
                        // Add pending player if there's one entered
                        if !newPlayerNumber.isEmpty {
                            addPlayer()
                        }
                        onSave()
                    }
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(teamName.isEmpty ? DS.textSecondary : DS.actionEdit)
                    .cornerRadius(12)
                    .disabled(teamName.isEmpty)
                }
                }
                .padding(28)
                .frame(width: 400)
                .background(DS.popupBackground)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 20)

                Spacer()
            }
            .padding(.top, 60)
        }
    }

    private func addPlayer() {
        guard let number = Int16(newPlayerNumber) else { return }

        let player = Player(context: viewContext)
        player.id = UUID()
        player.number = number
        player.name = newPlayerName.isEmpty ? nil : newPlayerName
        player.teamId = team.id

        newPlayerNumber = ""
        newPlayerName = ""
        numberFieldFocused = true
    }

    private func deletePlayer(_ player: Player) {
        viewContext.delete(player)
    }
}

struct SettingsPopup: View {
    let onClose: () -> Void
    @AppStorage("useWoodFloor") private var useWoodFloor = true
    @AppStorage("courtType") private var courtTypeRaw = CourtType.highSchool.rawValue

    private var courtType: CourtType {
        get { CourtType(rawValue: courtTypeRaw) ?? .highSchool }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 24) {
                HStack {
                    Text("Settings")
                        .font(.title.bold())
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(DS.iconDismiss)
                    }
                }

                // Court Type
                VStack(alignment: .leading, spacing: 12) {
                    Text("Court Type")
                        .font(.headline)
                        .foregroundColor(DS.textSecondary)

                    HStack(spacing: 8) {
                        ForEach(CourtType.allCases, id: \.rawValue) { type in
                            Button(action: { courtTypeRaw = type.rawValue }) {
                                Text(type.displayName)
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(courtType == type ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(courtType == type ? .white : DS.textPrimary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Court Appearance
                VStack(alignment: .leading, spacing: 12) {
                    Text("Court Floor")
                        .font(.headline)
                        .foregroundColor(DS.textSecondary)

                    HStack(spacing: 12) {
                        Button(action: { useWoodFloor = true }) {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.brown)
                                    .frame(height: 60)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(useWoodFloor ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                Text("Wood")
                                    .font(.subheadline.bold())
                                    .foregroundColor(useWoodFloor ? DS.textPrimary : DS.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Button(action: { useWoodFloor = false }) {
                            VStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.93, green: 0.87, blue: 0.75))
                                    .frame(height: 60)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(!useWoodFloor ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                                Text("Beige")
                                    .font(.subheadline.bold())
                                    .foregroundColor(!useWoodFloor ? DS.textPrimary : DS.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Done") {
                    onClose()
                }
                .font(.title3.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DS.actionEdit)
                .cornerRadius(12)
            }
            .padding(28)
            .frame(width: 350)
            .background(DS.popupBackground)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
