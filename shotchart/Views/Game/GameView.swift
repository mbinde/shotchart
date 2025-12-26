import SwiftUI
import CoreData

enum HistoryFilter {
    case quarter
    case h1
    case h2
    case all
}

struct GameView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var game: Game

    // Fetch shots for this game
    @FetchRequest private var shots: FetchedResults<Shot>
    // Fetch substitutions for this game
    @FetchRequest private var substitutions: FetchedResults<Substitution>
    // Fetch team for this game
    @FetchRequest private var teams: FetchedResults<Team>
    // Fetch players for the team
    @FetchRequest private var players: FetchedResults<Player>

    @State private var currentQuarter: Int16 = 1
    @State private var historyFilter: HistoryFilter = .quarter
    @State private var gameRoster: Set<Int16> = []
    @State private var showingStats = false

    // Player selection popup
    @State private var pendingShot: Shot?
    @State private var showingPlayerPopup = false
    @State private var newPlayerNumber = ""
    @State private var showingAddPlayer = false

    // Shot editing
    @State private var editingShot: Shot?
    @State private var relocatingShot: Shot?

    // On-court players (up to 5)
    @State private var onCourtPlayers: Set<Int16> = []
    @State private var showingOnCourtSelection = false
    @State private var showingTeamEditor = false
    @State private var playerToSubOut: Int16? = nil
    @State private var selectedPlayerNumber: Int16? = nil  // Pre-selected player for quick shot entry

    // Pending action while relocating (to show confirmation)
    @State private var showingCancelMoveAlert = false
    @State private var pendingAction: (() -> Void)? = nil

    // Delete confirmation
    @State private var shotToDelete: Shot? = nil
    @State private var showingDeleteConfirmation = false

    // Game name editing
    @State private var showingRenameAlert = false
    @State private var gameNameText = ""

    // Menu
    @State private var showingSettings = false

    // Shot filtering
    @State private var showingFilterPopup = false
    @State private var filterMade = true
    @State private var filterAttempt = true
    @State private var filter2P = true
    @State private var filter3P = true
    @State private var filterFT = true
    @State private var filterLA = true

    private var isFilterActive: Bool {
        !filterMade || !filterAttempt || !filter2P || !filter3P || !filterFT || !filterLA
    }

    // Settings
    @AppStorage("showLayup") private var showLayup = true
    @AppStorage("courtType") private var courtTypeRaw = CourtType.highSchool.rawValue

    init(game: Game) {
        self.game = game

        // Initialize fetch requests with predicates
        let shotsPredicate = NSPredicate(format: "gameId == %@", game.id! as CVarArg)
        _shots = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Shot.timestamp, ascending: true)],
            predicate: shotsPredicate
        )

        let subsPredicate = NSPredicate(format: "gameId == %@", game.id! as CVarArg)
        _substitutions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Substitution.timestamp, ascending: true)],
            predicate: subsPredicate
        )

        if let teamId = game.teamId {
            let teamPredicate = NSPredicate(format: "id == %@ AND archivedAt == nil", teamId as CVarArg)
            _teams = FetchRequest(
                sortDescriptors: [],
                predicate: teamPredicate
            )

            let playersPredicate = NSPredicate(format: "teamId == %@ AND archivedAt == nil", teamId as CVarArg)
            _players = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \Player.number, ascending: true)],
                predicate: playersPredicate
            )
        } else {
            // No team - empty results
            _teams = FetchRequest(
                sortDescriptors: [],
                predicate: NSPredicate(value: false)
            )
            _players = FetchRequest(
                sortDescriptors: [],
                predicate: NSPredicate(value: false)
            )
        }
    }

    private var team: Team? {
        teams.first
    }

    private var currentCourtType: CourtType {
        // Use team's court type if set, otherwise fall back to settings default (same as CourtView)
        if let courtTypeString = team?.courtType,
           let courtType = CourtType(rawValue: courtTypeString) {
            return courtType
        }
        return CourtType(rawValue: courtTypeRaw) ?? .highSchool
    }

    private var availablePlayers: [Int16] {
        // If we have on-court players selected, use those
        if !onCourtPlayers.isEmpty {
            return Array(onCourtPlayers).sorted()
        }
        // Otherwise fall back to full roster
        if game.teamId != nil {
            return players.map { $0.number }.sorted()
        } else {
            return Array(gameRoster).sorted()
        }
    }

    private var allTeamPlayers: [Player] {
        Array(players)
    }

    private var benchPlayers: [Player] {
        allTeamPlayers.filter { !onCourtPlayers.contains($0.number) }
    }

    private var filteredShots: [Shot] {
        // First filter by quarter/half
        let quarterFiltered: [Shot]
        switch historyFilter {
        case .quarter:
            quarterFiltered = shots.filter { $0.quarter == currentQuarter }
        case .h1:
            quarterFiltered = shots.filter { $0.quarter == 1 || $0.quarter == 2 }
        case .h2:
            quarterFiltered = shots.filter { $0.quarter == 3 || $0.quarter == 4 }
        case .all:
            quarterFiltered = Array(shots)
        }

        // Then apply type and result filters
        return quarterFiltered.filter { shot in
            // Check result filter
            let resultMatches = (shot.made && filterMade) || (!shot.made && filterAttempt)
            guard resultMatches else { return false }

            // Check type filter
            if shot.isLayup {
                return filterLA
            }
            guard let shotType = ShotType(rawValue: shot.type) else { return true }
            switch shotType {
            case .twoPointer: return filter2P
            case .threePointer: return filter3P
            case .freeThrow: return filterFT
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let courtAspect: CGFloat = 50.0 / 47.0
            let horizontalPadding: CGFloat = 40  // Space for margins around court
            let courtHeight = max(100, geo.size.height - 50)  // Leave room for help text
            let courtWidth = max(100, courtHeight * courtAspect)
            let sidebarWidth = max(100, geo.size.width - courtWidth - horizontalPadding)

            ZStack {
                // App background
                DS.appBackground
                    .ignoresSafeArea()

                HStack(spacing: 0) {
                    // Left sidebar with popup overlays
                    ZStack {
                        VStack(spacing: 12) {
                            // Menu and game title row
                            HStack(spacing: 12) {
                            Menu {
                                Button(action: {
                                    performOrConfirmCancelMove { showingStats = true }
                                }) {
                                    Label("Stats", systemImage: "chart.bar")
                                }
                                if game.teamId != nil {
                                    Button(action: {
                                        performOrConfirmCancelMove { showingOnCourtSelection = true }
                                    }) {
                                        Label("Team", systemImage: "person.3")
                                    }
                                }
                                Divider()
                                Button(action: { showingSettings = true }) {
                                    Label("Settings", systemImage: "gearshape")
                                }
                                Button(action: { dismiss() }) {
                                    Label("Return to Main Menu", systemImage: "house")
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(8)
                            }

                            Button(action: {
                                gameNameText = game.name ?? ""
                                showingRenameAlert = true
                            }) {
                                HStack(spacing: 6) {
                                    Text(game.name?.isEmpty == false ? game.name! : "Game")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                    Image(systemName: "pencil")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }

                        // Quarter tabs
                        HStack(spacing: 4) {
                            ForEach(1...4, id: \.self) { quarter in
                                Button(action: {
                                    performOrConfirmCancelMove {
                                        currentQuarter = Int16(quarter)
                                        historyFilter = .quarter
                                    }
                                }) {
                                    Text("Q\(quarter)")
                                        .font(.subheadline.bold())
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 32)
                                        .background(currentQuarter == Int16(quarter) && historyFilter == .quarter ? Color.white : Color.white.opacity(0.15))
                                        .foregroundColor(currentQuarter == Int16(quarter) && historyFilter == .quarter ? DS.appBackground : .white)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // History filter tabs (H1/H2/All) with filter button
                        HStack(spacing: 4) {
                            Button(action: {
                                performOrConfirmCancelMove { showingFilterPopup = true }
                            }) {
                                Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                    .background(isFilterActive ? Color.orange : Color.white.opacity(0.15))
                                    .foregroundColor(isFilterActive ? .white : .white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                performOrConfirmCancelMove { historyFilter = .h1 }
                            }) {
                                Text("H1")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(historyFilter == .h1 ? Color.white : Color.white.opacity(0.15))
                                    .foregroundColor(historyFilter == .h1 ? DS.appBackground : .white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                performOrConfirmCancelMove { historyFilter = .h2 }
                            }) {
                                Text("H2")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(historyFilter == .h2 ? Color.white : Color.white.opacity(0.15))
                                    .foregroundColor(historyFilter == .h2 ? DS.appBackground : .white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                performOrConfirmCancelMove { historyFilter = .all }
                            }) {
                                Text("All")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(historyFilter == .all ? Color.white : Color.white.opacity(0.15))
                                    .foregroundColor(historyFilter == .all ? DS.appBackground : .white)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        // Filtered indicator
                        if isFilterActive {
                            Text("Filtered")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                                .frame(maxWidth: .infinity)
                        }

                        // Shot history
                        VerticalShotHistoryView(
                            shots: filteredShots,
                            substitutions: Array(substitutions),
                            currentQuarter: currentQuarter,
                            historyFilter: historyFilter,
                            onEdit: { shot in
                                performOrConfirmCancelMove { editingShot = shot }
                            }
                        )

                        // On-court players row (5 slots)
                        if game.teamId != nil {
                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    let sortedPlayers = Array(onCourtPlayers).sorted()
                                    ForEach(0..<5, id: \.self) { index in
                                        if index < sortedPlayers.count {
                                            // Filled slot - show player number
                                            let number = sortedPlayers[index]
                                            let isSelected = selectedPlayerNumber == number
                                            Text("#\(number)")
                                                .font(.headline.bold())
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(isSelected ? Color.blue : Color.white.opacity(0.2))
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                                                )
                                                .onTapGesture {
                                                    performOrConfirmCancelMove {
                                                        if selectedPlayerNumber == number {
                                                            selectedPlayerNumber = nil
                                                        } else {
                                                            selectedPlayerNumber = number
                                                        }
                                                    }
                                                }
                                                .onLongPressGesture(minimumDuration: 0.5) {
                                                    performOrConfirmCancelMove {
                                                        playerToSubOut = number
                                                    }
                                                }
                                        } else {
                                            // Empty slot - dashed box with person icon
                                            Button(action: {
                                                performOrConfirmCancelMove { showingOnCourtSelection = true }
                                            }) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                                                        .foregroundColor(.white.opacity(0.4))
                                                    Image(systemName: "person.badge.plus")
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.4))
                                                }
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 36)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                // Helper text
                                if onCourtPlayers.count >= 2 {
                                    Text("tap to select • hold to sub")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        }

                        if relocatingShot != nil {
                            Button("Cancel Move") {
                                relocatingShot = nil
                                // Return to popup without moving
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(8)
                        }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)

                        // Player selection popup overlay (over sidebar)
                        if showingPlayerPopup, let shot = pendingShot, relocatingShot == nil {
                            PlayerPopupOverlay(
                                shot: shot,
                                availablePlayers: availablePlayers,
                                onSelectPlayer: { number in
                                    shot.playerNumber = number
                                    // Look up player to set playerId if we have a team
                                    if let player = players.first(where: { $0.number == number }) {
                                        shot.playerId = player.id
                                    }
                                    if game.teamId == nil {
                                        gameRoster.insert(number)
                                    }
                                    save()
                                    showingPlayerPopup = false
                                    pendingShot = nil
                                },
                                onAddPlayer: { showingAddPlayer = true },
                                onSkip: {
                                    showingPlayerPopup = false
                                    pendingShot = nil
                                },
                                onToggleMade: { made in
                                    shot.made = made
                                    save()
                                },
                                onCancel: {
                                    viewContext.delete(shot)
                                    save()
                                    showingPlayerPopup = false
                                    pendingShot = nil
                                },
                                onMove: {
                                    relocatingShot = shot
                                    // Keep pendingShot set so we return to this popup after moving
                                }
                            )
                        }

                        // Shot editor popup (over sidebar)
                        if let shot = editingShot, relocatingShot == nil {
                            ShotEditorPopup(
                                shot: shot,
                                availablePlayers: availablePlayers,
                                players: Array(players),
                                onDone: {
                                    save()
                                    editingShot = nil
                                },
                                onDelete: {
                                    deleteShot(shot)
                                    editingShot = nil
                                },
                                onRelocate: {
                                    relocatingShot = shot
                                    // Keep editingShot set so we return to this popup after moving
                                }
                            )
                        }
                    }
                    .frame(width: max(sidebarWidth, 200))

                    // Right side - Court
                    VStack(spacing: 4) {
                        CourtView(shots: filteredShots, relocatingShot: relocatingShot, theme: team?.useCustomCourtTheme == true ? team?.courtTheme : nil, teamCourtType: team?.courtType) { location, made in
                            if let shot = relocatingShot {
                                shot.x = location.x
                                shot.y = location.y
                                shot.type = ShotType.detect(
                                    x: location.x,
                                    y: location.y,
                                    threePointArc: Double(currentCourtType.threePointArc),
                                    threePointCorner: Double(currentCourtType.threePointCornerDistance)
                                ).rawValue
                                save()
                                relocatingShot = nil
                            } else {
                                recordShot(at: location, made: made)
                            }
                        }
                        .frame(width: courtWidth, height: courtHeight)
                        .overlay(alignment: .top) {
                            if relocatingShot != nil {
                                Text("TAP NEW LOCATION")
                                    .font(.title.bold())
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 14)
                                    .background(Color.yellow)
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.3), radius: 8)
                                    .padding(.top, 20)
                            } else if isFilterActive {
                                Text("FILTERED VIEW")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange)
                                    .cornerRadius(8)
                                    .padding(.top, 8)
                            }
                        }

                        Text("Single tap = attempt  •  Double tap = make")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.leading, 8)

                    Spacer()
                        .frame(width: 16)
                }

                // On-court selection popup
                if showingOnCourtSelection, let team = team {
                    OnCourtSelectionPopup(
                        team: team,
                        players: Array(players),
                        onCourtPlayers: $onCourtPlayers,
                        onDone: { showingOnCourtSelection = false },
                        onEditTeam: {
                            showingOnCourtSelection = false
                            showingTeamEditor = true
                        }
                    )
                }

                // Team editor popup
                if showingTeamEditor, let team = team {
                    TeamEditorPopup(
                        team: team,
                        players: Array(players),
                        onSave: {
                            save()
                            showingTeamEditor = false
                        },
                        onCancel: {
                            showingTeamEditor = false
                        }
                    )
                }

                // Substitution popup
                if let subOutNumber = playerToSubOut {
                    SubstitutionPopup(
                        playerOut: subOutNumber,
                        benchPlayers: benchPlayers,
                        onSubIn: { playerIn in
                            let sub = Substitution(context: viewContext)
                            sub.id = UUID()
                            sub.quarter = currentQuarter
                            sub.playerOut = subOutNumber
                            sub.playerIn = playerIn.number
                            sub.timestamp = Date()
                            sub.gameId = game.id
                            save()
                            // Clear selection if this player was selected
                            if selectedPlayerNumber == subOutNumber {
                                selectedPlayerNumber = nil
                            }
                            onCourtPlayers.remove(subOutNumber)
                            onCourtPlayers.insert(playerIn.number)
                            playerToSubOut = nil
                        },
                        onRemoveOnly: {
                            let sub = Substitution(context: viewContext)
                            sub.id = UUID()
                            sub.quarter = currentQuarter
                            sub.playerOut = subOutNumber
                            sub.playerIn = 0  // 0 means no replacement
                            sub.timestamp = Date()
                            sub.gameId = game.id
                            save()
                            // Clear selection if this player was selected
                            if selectedPlayerNumber == subOutNumber {
                                selectedPlayerNumber = nil
                            }
                            onCourtPlayers.remove(subOutNumber)
                            playerToSubOut = nil
                        },
                        onCancel: { playerToSubOut = nil }
                    )
                }

                // Settings popup
                if showingSettings {
                    SettingsPopup(onClose: { showingSettings = false })
                }

                // Filter popup
                if showingFilterPopup {
                    ShotFilterPopup(
                        filterMade: $filterMade,
                        filterAttempt: $filterAttempt,
                        filter2P: $filter2P,
                        filter3P: $filter3P,
                        filterFT: $filterFT,
                        filterLA: $filterLA,
                        onClose: { showingFilterPopup = false },
                        onSelectAll: {
                            filterMade = true
                            filterAttempt = true
                            filter2P = true
                            filter3P = true
                            filterFT = true
                            filterLA = true
                        },
                        onSelectNone: {
                            filterMade = false
                            filterAttempt = false
                            filter2P = false
                            filter3P = false
                            filterFT = false
                            filterLA = false
                        }
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingStats) {
            StatsContainerView(game: game)
                .presentationBackground(.clear)
        }
        .alert("Add Player", isPresented: $showingAddPlayer) {
            TextField("Jersey Number", text: $newPlayerNumber)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { newPlayerNumber = "" }
            Button("Add") {
                if let number = Int16(newPlayerNumber), let shot = pendingShot {
                    shot.playerNumber = number
                    gameRoster.insert(number)
                    save()
                }
                newPlayerNumber = ""
                showingPlayerPopup = false
                pendingShot = nil
            }
        }
        .alert("Cancel Shot Move?", isPresented: $showingCancelMoveAlert) {
            Button("Keep Moving", role: .cancel) {
                pendingAction = nil
            }
            Button("Cancel Move", role: .destructive) {
                relocatingShot = nil
                pendingShot = nil
                editingShot = nil
                pendingAction?()
                pendingAction = nil
            }
        } message: {
            Text("You're in the middle of moving a shot. Do you want to cancel the move?")
        }
        .alert("Delete Shot?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                shotToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let shot = shotToDelete {
                    deleteShot(shot)
                }
                shotToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this shot? This cannot be undone.")
        }
        .alert("Name This Game", isPresented: $showingRenameAlert) {
            TextField("Game name", text: $gameNameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                game.name = gameNameText.isEmpty ? nil : gameNameText
                save()
            }
        } message: {
            Text("Enter a name for this game")
        }
        .onAppear {
            initializeRoster()
        }
        .onChange(of: onCourtPlayers) { _, newPlayers in
            // Clear selection if the selected player is no longer on court
            if let selected = selectedPlayerNumber, !newPlayers.contains(selected) {
                selectedPlayerNumber = nil
            }
            // Persist to Core Data
            saveOnCourtPlayers()
        }
    }

    private func initializeRoster() {
        if game.teamId == nil {
            for shot in shots {
                if shot.playerNumber > 0 {
                    gameRoster.insert(shot.playerNumber)
                }
            }
        }
        // Load persisted on-court players
        loadOnCourtPlayers()
    }

    private func loadOnCourtPlayers() {
        if let stored = game.teamOnCourt, !stored.isEmpty {
            let numbers = stored.split(separator: ",")
                .compactMap { Int16($0.trimmingCharacters(in: .whitespaces)) }
            onCourtPlayers = Set(numbers)
        }
    }

    private func saveOnCourtPlayers() {
        let numberStrings = onCourtPlayers.sorted().map { String($0) }
        game.teamOnCourt = numberStrings.joined(separator: ",")
        save()
    }

    private func recordShot(at location: CGPoint, made: Bool) {
        let shot = Shot(context: viewContext)
        shot.id = UUID()
        shot.x = location.x
        shot.y = location.y
        shot.made = made
        shot.playerNumber = 0
        shot.quarter = currentQuarter
        shot.timestamp = Date()
        shot.gameId = game.id

        let detectedType = ShotType.detect(
            x: location.x,
            y: location.y,
            threePointArc: Double(currentCourtType.threePointArc),
            threePointCorner: Double(currentCourtType.threePointCornerDistance)
        )
        shot.type = detectedType.rawValue

        // Auto-detect layup if within 5 feet of basket (only if layup tracking is enabled)
        if showLayup {
            let distance = ShotType.distanceFromBasket(x: location.x, y: location.y)
            shot.isLayup = distance <= 5.0
        } else {
            shot.isLayup = false
        }

        // If a player is pre-selected, assign them and skip the popup
        if let preSelectedPlayer = selectedPlayerNumber {
            shot.playerNumber = preSelectedPlayer
            // Look up player to set playerId if we have a team
            if let player = players.first(where: { $0.number == preSelectedPlayer }) {
                shot.playerId = player.id
            }
        }

        do {
            try viewContext.save()
            // Only show popup if no player was pre-selected
            if selectedPlayerNumber == nil {
                pendingShot = shot
                showingPlayerPopup = true
            }
        } catch {
            print("Error recording shot: \(error)")
        }
    }

    private func deleteShot(_ shot: Shot) {
        viewContext.delete(shot)
        save()
    }

    private func performOrConfirmCancelMove(_ action: @escaping () -> Void) {
        if relocatingShot != nil {
            pendingAction = action
            showingCancelMoveAlert = true
        } else {
            action()
        }
    }

    private func save() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error)")
        }
    }
}

struct PlayerPopupOverlay: View {
    @ObservedObject var shot: Shot
    let availablePlayers: [Int16]
    let onSelectPlayer: (Int16) -> Void
    let onAddPlayer: () -> Void
    let onSkip: () -> Void
    let onToggleMade: (Bool) -> Void
    let onCancel: () -> Void
    let onMove: () -> Void

    // Settings
    @AppStorage("showLayup") private var showLayup = true
    @AppStorage("useAbbreviations") private var useAbbreviations = true

    private func shotTypeDisplayName(_ type: ShotType) -> String {
        if useAbbreviations {
            return type.displayName
        } else {
            switch type {
            case .twoPointer: return "2-Pointer"
            case .threePointer: return "3-Pointer"
            case .freeThrow: return "Free Throw"
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture { onSkip() }

            VStack(spacing: 24) {
                // Made/Missed toggle
                HStack(spacing: 0) {
                    Button(action: { onToggleMade(false) }) {
                        Text("MISS")
                            .font(.title.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(!shot.made ? Color.red : Color.gray.opacity(0.2))
                            .foregroundColor(!shot.made ? .white : .secondary)
                    }
                    Button(action: { onToggleMade(true) }) {
                        Text("MAKE")
                            .font(.title.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(shot.made ? Color.green : Color.gray.opacity(0.2))
                            .foregroundColor(shot.made ? .white : .secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Shot type selector
                HStack(spacing: 8) {
                    ForEach(ShotType.allCases, id: \.self) { type in
                        Button(action: { shot.type = type.rawValue }) {
                            Text(shotTypeDisplayName(type))
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(shot.type == type.rawValue ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(shot.type == type.rawValue ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }
                }

                // Layup toggle - only show when within 8 feet of basket
                if showLayup && ShotType.distanceFromBasket(x: shot.x, y: shot.y) <= 8.0 {
                    Button(action: { shot.isLayup.toggle() }) {
                        HStack {
                            Image(systemName: shot.isLayup ? "checkmark.square.fill" : "square")
                                .font(.title2)
                            Text(useAbbreviations ? "LA" : "Layup")
                                .font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(shot.isLayup ? Color.orange : Color.orange.opacity(0.3))
                        .foregroundColor(shot.isLayup ? .white : .orange)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                    }
                }

                // Player grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], spacing: 8) {
                    ForEach(availablePlayers, id: \.self) { number in
                        let isSelected = shot.playerNumber == number
                        Button(action: { onSelectPlayer(number) }) {
                            Text("#\(number)")
                                .font(.title2.bold())
                                .frame(width: 60, height: 54)
                                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(isSelected ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }

                    Button(action: onSkip) {
                        Text("--")
                            .font(.title2.bold())
                            .frame(width: 60, height: 54)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }

                    Button(action: onAddPlayer) {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .frame(width: 60, height: 54)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                }

                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.title3.bold())
                            .foregroundColor(.red)
                    }

                    Spacer()

                    Button(action: onMove) {
                        Label("Move shot", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.title3.bold())
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    Button(action: onSkip) {
                        Text("Done")
                            .font(.title3.bold())
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(width: 420)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ShotHistoryView: View {
    let shots: [Shot]
    let onEdit: (Shot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Shot History")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(shots.reversed().prefix(20), id: \.id) { shot in
                        ShotHistoryItem(shot: shot)
                            .onTapGesture { onEdit(shot) }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 70)
    }
}

struct VerticalShotHistoryView: View {
    let shots: [Shot]
    let substitutions: [Substitution]
    let currentQuarter: Int16
    let historyFilter: HistoryFilter
    let onEdit: (Shot) -> Void

    private var filteredSubs: [Substitution] {
        switch historyFilter {
        case .quarter:
            return substitutions.filter { $0.quarter == currentQuarter }
        case .h1:
            return substitutions.filter { $0.quarter == 1 || $0.quarter == 2 }
        case .h2:
            return substitutions.filter { $0.quarter == 3 || $0.quarter == 4 }
        case .all:
            return substitutions
        }
    }

    // Combined events sorted by timestamp
    private var events: [GameEvent] {
        var result: [GameEvent] = []
        for shot in shots {
            result.append(.shot(shot))
        }
        for sub in filteredSubs {
            result.append(.substitution(sub))
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 8) {
            if events.isEmpty {
                Spacer()
                Text("No events")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 6) {
                            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                                switch event {
                                case .shot(let shot):
                                    MiniShotHistoryItem(
                                        shot: shot,
                                        shotNumber: index + 1,
                                        onEdit: { onEdit(shot) }
                                    )
                                    .id(event.id)
                                case .substitution(let sub):
                                    MiniSubHistoryItem(sub: sub, eventNumber: index + 1)
                                        .id(event.id)
                                }
                            }
                        }
                    }
                    .onChange(of: events.count) {
                        if let lastEvent = events.last {
                            withAnimation {
                                proxy.scrollTo(lastEvent.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
}

enum GameEvent: Identifiable {
    case shot(Shot)
    case substitution(Substitution)

    var id: UUID {
        switch self {
        case .shot(let shot): return shot.id ?? UUID()
        case .substitution(let sub): return sub.id ?? UUID()
        }
    }

    var timestamp: Date {
        switch self {
        case .shot(let shot): return shot.timestamp ?? Date()
        case .substitution(let sub): return sub.timestamp ?? Date()
        }
    }
}

struct MiniSubHistoryItem: View {
    let sub: Substitution
    let eventNumber: Int

    private var timeString: String {
        guard let timestamp = sub.timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: timestamp)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(eventNumber).")
                .font(.body.bold().monospacedDigit())
                .foregroundColor(.black.opacity(0.6))
                .frame(width: 28, alignment: .leading)

            Image(systemName: "arrow.left.arrow.right")
                .font(.body)
                .foregroundColor(.purple)

            if sub.playerIn > 0 {
                Text("#\(sub.playerOut)")
                    .font(.body)
                    .foregroundColor(.red)
                Text("→")
                    .foregroundColor(.black.opacity(0.6))
                Text("#\(sub.playerIn)")
                    .font(.body)
                    .foregroundColor(.green)
            } else {
                Text("#\(sub.playerOut)")
                    .font(.body)
                    .foregroundColor(.red)
                Text("out")
                    .font(.body)
                    .foregroundColor(.black.opacity(0.6))
            }

            Spacer()

            Text(timeString)
                .font(.caption)
                .foregroundColor(.black.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.85))
        .cornerRadius(8)
    }
}

struct MiniShotHistoryItem: View {
    @ObservedObject var shot: Shot
    let shotNumber: Int
    let onEdit: () -> Void

    private var timeString: String {
        guard let timestamp = shot.timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: timestamp)
    }

    private var shotDisplayName: String {
        let suffix = shot.made ? "M" : "A"
        if shot.isLayup {
            return "LA\(suffix)"
        }
        guard let shotType = ShotType(rawValue: shot.type) else { return "?" }
        switch shotType {
        case .twoPointer: return "2P\(suffix)"
        case .threePointer: return "3P\(suffix)"
        case .freeThrow: return "FT\(suffix)"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(shotNumber).")
                .font(.body.bold().monospacedDigit())
                .foregroundColor(.black.opacity(0.6))
                .frame(width: 28, alignment: .leading)

            Circle()
                .fill(shot.made ? Color.green : Color.red)
                .frame(width: 14, height: 14)

            Text(shotDisplayName)
                .font(.body.bold())
                .foregroundColor(.black)

            if shot.playerNumber > 0 {
                Text("#\(shot.playerNumber)")
                    .font(.body)
                    .foregroundColor(.black.opacity(0.7))
            }

            Spacer()

            Text(timeString)
                .font(.body.monospacedDigit())
                .foregroundColor(.black.opacity(0.7))

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.body)
                    .foregroundColor(.black.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.85))
        .cornerRadius(8)
    }
}

struct ShotHistoryItem: View {
    @ObservedObject var shot: Shot

    private var shotDisplayName: String {
        let suffix = shot.made ? "M" : "A"
        if shot.isLayup {
            return "LA\(suffix)"
        }
        guard let shotType = ShotType(rawValue: shot.type) else { return "?" }
        switch shotType {
        case .twoPointer: return "2P\(suffix)"
        case .threePointer: return "3P\(suffix)"
        case .freeThrow: return "FT\(suffix)"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(shot.made ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                    .frame(width: 36, height: 36)

                Text(shotDisplayName)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
            }

            Text(shot.playerNumber > 0 ? "#\(shot.playerNumber)" : "-")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("Q\(shot.quarter)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}

struct ShotEditorPopup: View {
    @ObservedObject var shot: Shot
    let availablePlayers: [Int16]
    let players: [Player]
    let onDone: () -> Void
    let onDelete: () -> Void
    let onRelocate: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture { onDone() }

            VStack(spacing: 24) {
                Text("Edit Shot")
                    .font(.title.bold())

                // Made/Missed toggle
                HStack(spacing: 0) {
                    Button(action: { shot.made = false }) {
                        Text("MISS")
                            .font(.title.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(!shot.made ? Color.red : Color.gray.opacity(0.2))
                            .foregroundColor(!shot.made ? .white : .secondary)
                    }
                    Button(action: { shot.made = true }) {
                        Text("MAKE")
                            .font(.title.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(shot.made ? Color.green : Color.gray.opacity(0.2))
                            .foregroundColor(shot.made ? .white : .secondary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Shot type
                HStack(spacing: 8) {
                    ForEach(ShotType.allCases, id: \.self) { type in
                        Button(action: { shot.type = type.rawValue }) {
                            Text(type.displayName)
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(shot.type == type.rawValue ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(shot.type == type.rawValue ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }
                }

                // Player selection
                VStack(spacing: 8) {
                    Text("Player")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 60), spacing: 8)
                    ], spacing: 8) {
                        ForEach(availablePlayers, id: \.self) { number in
                            Button(action: {
                                shot.playerNumber = number
                                // Look up player to set playerId
                                if let player = players.first(where: { $0.number == number }) {
                                    shot.playerId = player.id
                                }
                            }) {
                                Text("#\(number)")
                                    .font(.title3.bold())
                                    .frame(width: 60, height: 50)
                                    .background(shot.playerNumber == number ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(shot.playerNumber == number ? .white : .primary)
                                    .cornerRadius(10)
                            }
                        }
                        // No player option
                        Button(action: {
                            shot.playerNumber = 0
                            shot.playerId = nil
                        }) {
                            Text("--")
                                .font(.title3.bold())
                                .frame(width: 60, height: 50)
                                .background(shot.playerNumber == 0 ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(shot.playerNumber == 0 ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }
                }

                // Actions
                HStack(spacing: 16) {
                    Button(action: onRelocate) {
                        Label("Move shot", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
                .padding(.top, 8)

                Button(action: onDone) {
                    Text("Done")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(width: 340)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OnCourtSelectionPopup: View {
    let team: Team
    let players: [Player]
    @Binding var onCourtPlayers: Set<Int16>
    let onDone: () -> Void
    let onEditTeam: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDone() }

            VStack(spacing: 20) {
                HStack {
                    Text("On Court")
                        .font(.title.bold())
                    Spacer()
                    Text("\(onCourtPlayers.count)/5")
                        .font(.title2)
                        .foregroundColor(onCourtPlayers.count == 5 ? .green : .secondary)
                }

                if players.isEmpty {
                    Text("No players on roster")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(players, id: \.id) { player in
                                PlayerSelectionRow(
                                    player: player,
                                    isSelected: onCourtPlayers.contains(player.number),
                                    onToggle: {
                                        if onCourtPlayers.contains(player.number) {
                                            onCourtPlayers.remove(player.number)
                                        } else if onCourtPlayers.count < 5 {
                                            onCourtPlayers.insert(player.number)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }

                HStack(spacing: 16) {
                    Button(action: onEditTeam) {
                        Label("Edit team details", systemImage: "pencil")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    if !onCourtPlayers.isEmpty {
                        Button(action: { onCourtPlayers.removeAll() }) {
                            Text("Clear")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Button(action: onDone) {
                    Text("Done")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .frame(width: 360)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

struct PlayerSelectionRow: View {
    let player: Player
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text("#\(player.number)")
                    .font(.title2.bold())
                    .frame(width: 60, alignment: .leading)

                if let name = player.name, !name.isEmpty {
                    Text(name)
                        .font(.title3)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .green : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct SubstitutionPopup: View {
    let playerOut: Int16
    let benchPlayers: [Player]
    let onSubIn: (Player) -> Void
    let onRemoveOnly: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 20) {
                Text("Sub out #\(playerOut)")
                    .font(.title.bold())

                Text("Who's coming in?")
                    .font(.headline)
                    .foregroundColor(.secondary)

                ScrollView {
                    VStack(spacing: 8) {
                        // No replacement option
                        Button(action: onRemoveOnly) {
                            HStack {
                                Text("No one")
                                    .font(.title2.bold())
                                    .foregroundColor(.secondary)

                                Spacer()

                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)

                        ForEach(benchPlayers, id: \.id) { player in
                            Button(action: { onSubIn(player) }) {
                                HStack {
                                    Text("#\(player.number)")
                                        .font(.title2.bold())
                                        .frame(width: 60, alignment: .leading)

                                    if let name = player.name, !name.isEmpty {
                                        Text(name)
                                            .font(.title3)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.green)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 280)

                Button("Cancel") {
                    onCancel()
                }
                .font(.title3.bold())
                .foregroundColor(.red)
            }
            .padding(28)
            .frame(width: 340)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

struct ShotFilterPopup: View {
    @Binding var filterMade: Bool
    @Binding var filterAttempt: Bool
    @Binding var filter2P: Bool
    @Binding var filter3P: Bool
    @Binding var filterFT: Bool
    @Binding var filterLA: Bool
    let onClose: () -> Void
    let onSelectAll: () -> Void
    let onSelectNone: () -> Void

    private var isAllSelected: Bool {
        filterMade && filterAttempt && filter2P && filter3P && filterFT && filterLA
    }

    private var isNoneSelected: Bool {
        !filterMade && !filterAttempt && !filter2P && !filter3P && !filterFT && !filterLA
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 20) {
                HStack {
                    Text("Filter Shots")
                        .font(.title2.bold())
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(DS.iconDismiss)
                    }
                }

                // Result filters
                VStack(alignment: .leading, spacing: 8) {
                    Text("Result")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        FilterToggleButton(label: "Made", isOn: $filterMade)
                        FilterToggleButton(label: "Attempt", isOn: $filterAttempt)
                    }
                }

                // Shot type filters
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shot Type")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        FilterToggleButton(label: "2P", isOn: $filter2P)
                        FilterToggleButton(label: "3P", isOn: $filter3P)
                        FilterToggleButton(label: "FT", isOn: $filterFT)
                        FilterToggleButton(label: "LA", isOn: $filterLA)
                    }
                }

                HStack(spacing: 12) {
                    Button(action: onSelectAll) {
                        Text("All")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isAllSelected ? Color.gray : Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(isAllSelected)

                    Button(action: onSelectNone) {
                        Text("None")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isNoneSelected ? Color.gray : Color.orange)
                            .cornerRadius(8)
                    }
                    .disabled(isNoneSelected)

                    Spacer()

                    Button(action: onClose) {
                        Text("Done")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .frame(width: 300)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

struct FilterToggleButton: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn ? .blue : .gray)
                Text(label)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isOn ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .foregroundColor(isOn ? .blue : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let game = Game(context: context)
    game.id = UUID()
    game.date = Date()

    return NavigationStack {
        GameView(game: game)
    }
    .environment(\.managedObjectContext, context)
}
