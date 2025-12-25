import SwiftUI
import CoreData

struct GameView: View {
    @Environment(\.managedObjectContext) private var viewContext
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

    // Pending action while relocating (to show confirmation)
    @State private var showingCancelMoveAlert = false
    @State private var pendingAction: (() -> Void)? = nil

    // Delete confirmation
    @State private var shotToDelete: Shot? = nil
    @State private var showingDeleteConfirmation = false

    // Game name editing
    @State private var showingRenameAlert = false
    @State private var gameNameText = ""

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
            let teamPredicate = NSPredicate(format: "id == %@", teamId as CVarArg)
            _teams = FetchRequest(
                sortDescriptors: [],
                predicate: teamPredicate
            )

            let playersPredicate = NSPredicate(format: "teamId == %@", teamId as CVarArg)
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
                    // Left sidebar
                    VStack(spacing: 12) {
                        // Quarter tabs
                        HStack(spacing: 4) {
                            ForEach(1...4, id: \.self) { quarter in
                                Button(action: {
                                    performOrConfirmCancelMove { currentQuarter = Int16(quarter) }
                                }) {
                                    Text("Q\(quarter)")
                                        .font(.title3.bold())
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(currentQuarter == Int16(quarter) ? Color.white : Color.white.opacity(0.15))
                                        .foregroundColor(currentQuarter == Int16(quarter) ? DS.appBackground : .white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Shot history
                        VerticalShotHistoryView(
                            shots: Array(shots),
                            substitutions: Array(substitutions),
                            currentQuarter: currentQuarter,
                            onEdit: { shot in
                                performOrConfirmCancelMove { editingShot = shot }
                            },
                            onDelete: { shot in
                                performOrConfirmCancelMove {
                                    shotToDelete = shot
                                    showingDeleteConfirmation = true
                                }
                            }
                        )

                        // On-court players row
                        if game.teamId != nil {
                            if onCourtPlayers.isEmpty {
                                Button(action: {
                                    performOrConfirmCancelMove { showingOnCourtSelection = true }
                                }) {
                                    HStack {
                                        Image(systemName: "person.3")
                                        Text("Select Players on Court")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.15))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            } else {
                                HStack(spacing: 6) {
                                    ForEach(Array(onCourtPlayers).sorted(), id: \.self) { number in
                                        Button(action: {
                                            performOrConfirmCancelMove { playerToSubOut = number }
                                        }) {
                                            Text("#\(number)")
                                                .font(.headline.bold())
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(Color.white.opacity(0.2))
                                                .foregroundColor(.white)
                                                .cornerRadius(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Controls at bottom
                        HStack(spacing: 8) {
                            Button(action: {
                                performOrConfirmCancelMove { showingStats = true }
                            }) {
                                Label("Stats", systemImage: "chart.bar")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.15))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            if game.teamId != nil {
                                Button(action: {
                                    performOrConfirmCancelMove { showingOnCourtSelection = true }
                                }) {
                                    Label("Team", systemImage: "person.3")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.15))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
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
                    .frame(width: max(sidebarWidth, 200))
                    .padding(12)

                    // Right side - Court
                    VStack(spacing: 4) {
                        CourtView(shots: Array(shots), relocatingShot: relocatingShot) { location, made in
                            if let shot = relocatingShot {
                                shot.x = location.x
                                shot.y = location.y
                                shot.type = ShotType.detect(x: location.x, y: location.y).rawValue
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
                            }
                        }

                        Text("Single tap = miss  •  Double tap = make")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.leading, 8)

                    Spacer()
                        .frame(width: 16)
                }

                // Player selection popup overlay
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

                // Shot editor popup
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
                            onCourtPlayers.remove(subOutNumber)
                            playerToSubOut = nil
                        },
                        onCancel: { playerToSubOut = nil }
                    )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    gameNameText = game.name ?? ""
                    showingRenameAlert = true
                }) {
                    HStack(spacing: 6) {
                        Text(game.name?.isEmpty == false ? game.name! : "Game")
                            .font(.headline)
                            .foregroundColor(.white)
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
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
    }

    private func initializeRoster() {
        if game.teamId == nil {
            for shot in shots {
                if shot.playerNumber > 0 {
                    gameRoster.insert(shot.playerNumber)
                }
            }
        }
    }

    private func recordShot(at location: CGPoint, made: Bool) {
        let shot = Shot(context: viewContext)
        shot.id = UUID()
        shot.x = location.x
        shot.y = location.y
        shot.made = made
        shot.isLayup = false
        shot.playerNumber = 0
        shot.quarter = currentQuarter
        shot.timestamp = Date()
        shot.gameId = game.id

        let detectedType = ShotType.detect(x: location.x, y: location.y)
        shot.type = detectedType.rawValue

        do {
            try viewContext.save()
            pendingShot = shot
            showingPlayerPopup = true
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

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
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

                // Player grid
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 8)], spacing: 8) {
                    ForEach(availablePlayers, id: \.self) { number in
                        Button(action: { onSelectPlayer(number) }) {
                            Text("#\(number)")
                                .font(.title2.bold())
                                .frame(width: 60, height: 54)
                                .background(Color.blue)
                                .foregroundColor(.white)
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
                            .background(Color.blue.opacity(0.3))
                            .foregroundColor(.blue)
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
    let onEdit: (Shot) -> Void
    let onDelete: (Shot) -> Void

    private var quarterShots: [Shot] {
        shots.filter { $0.quarter == currentQuarter }
    }

    private var quarterSubs: [Substitution] {
        substitutions.filter { $0.quarter == currentQuarter }
    }

    // Combined events sorted by timestamp
    private var events: [GameEvent] {
        var result: [GameEvent] = []
        for shot in quarterShots {
            result.append(.shot(shot))
        }
        for sub in quarterSubs {
            result.append(.substitution(sub))
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Q\(currentQuarter) History")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))

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
                                        onEdit: { onEdit(shot) },
                                        onDelete: { onDelete(shot) }
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
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 28, alignment: .leading)

            Image(systemName: "arrow.left.arrow.right")
                .font(.body)
                .foregroundColor(.purple)

            if sub.playerIn > 0 {
                Text("#\(sub.playerOut)")
                    .font(.body)
                    .foregroundColor(.red)
                Text("→")
                    .foregroundColor(.white.opacity(0.6))
                Text("#\(sub.playerIn)")
                    .font(.body)
                    .foregroundColor(.green)
            } else {
                Text("#\(sub.playerOut)")
                    .font(.body)
                    .foregroundColor(.red)
                Text("out")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Text(timeString)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MiniShotHistoryItem: View {
    @ObservedObject var shot: Shot
    let shotNumber: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var timeString: String {
        guard let timestamp = shot.timestamp else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: timestamp)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(shotNumber).")
                .font(.body.bold().monospacedDigit())
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 28, alignment: .leading)

            Circle()
                .fill(shot.made ? Color.green : Color.red)
                .frame(width: 14, height: 14)

            Text(ShotType(rawValue: shot.type)?.displayName ?? "?")
                .font(.body.bold())
                .foregroundColor(.white)

            if shot.playerNumber > 0 {
                Text("#\(shot.playerNumber)")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(timeString)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ShotHistoryItem: View {
    @ObservedObject var shot: Shot

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(shot.made ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                    .frame(width: 32, height: 32)

                Text(ShotType(rawValue: shot.type)?.displayName ?? "?")
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
                .ignoresSafeArea()
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
                        Label("Edit Roster", systemImage: "pencil")
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
