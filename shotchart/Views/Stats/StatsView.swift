import SwiftUI
import CoreData
import QuickLook

struct StatsContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var game: Game
    @State private var isExpanded = false
    @State private var pdfURL: URL?
    @State private var previewURL: URL?  // Separate state for Quick Look
    @State private var showExportError = false

    @FetchRequest private var shots: FetchedResults<Shot>
    @FetchRequest private var teams: FetchedResults<Team>
    @FetchRequest private var players: FetchedResults<Player>

    init(game: Game) {
        self.game = game

        let shotsPredicate = NSPredicate(format: "gameId == %@", game.id! as CVarArg)
        _shots = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Shot.timestamp, ascending: true)],
            predicate: shotsPredicate
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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed background when not expanded
                Color.black.opacity(isExpanded ? 0 : 0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !isExpanded {
                            dismiss()
                        }
                    }

                // Stats content
                NavigationStack {
                    StatsView(game: game)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isExpanded.toggle()
                                    }
                                }) {
                                    Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                        .font(.headline)
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                HStack(spacing: 16) {
                                    if pdfURL != nil {
                                        // Preview button (eye icon)
                                        Button(action: { previewURL = pdfURL }) {
                                            Image(systemName: "eye")
                                                .font(.headline)
                                        }
                                        // Share button
                                        Button(action: sharePDF) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.headline)
                                        }
                                    } else {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Button("Done") { dismiss() }
                                        .font(.headline)
                                }
                            }
                        }
                }
                .background(Color(.systemBackground))
                .frame(
                    width: isExpanded ? geometry.size.width : min(geometry.size.width * 0.85, 700),
                    height: isExpanded ? geometry.size.height : min(geometry.size.height * 0.8, 600)
                )
                .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 20))
                .shadow(color: isExpanded ? .clear : .black.opacity(0.3), radius: 20)
            }
        }
        .background(Color.clear)
        .onAppear {
            exportPDF()
        }
        .alert("Export Failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Could not generate PDF. Please try again.")
        }
        .quickLookPreview($previewURL)
    }

    private func sharePDF() {
        guard let url = pdfURL else { return }

        // Get the root view controller and present from there
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // For iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: 100, width: 0, height: 0)
        }

        // Find the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(activityVC, animated: true)
    }

    private func exportPDF() {
        // Don't regenerate if we already have a PDF
        guard pdfURL == nil else { return }

        let playerData = players.map { (number: $0.number, name: $0.name) }

        guard let pdfData = generateStatsPDF(
            gameDate: game.date ?? Date(),
            teamName: team?.name,
            shots: Array(shots),
            playerData: playerData
        ) else {
            showExportError = true
            return
        }

        // Create filename based on game info
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: game.date ?? Date())
        let teamPart = team?.name?.replacingOccurrences(of: " ", with: "_") ?? "Game"
        let filename = "Stats_\(teamPart)_\(dateString).pdf"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try pdfData.write(to: tempURL)
            pdfURL = tempURL
        } catch {
            showExportError = true
        }
    }
}

struct StatsView: View {
    @ObservedObject var game: Game
    @State private var selectedTab = 0

    @FetchRequest private var shots: FetchedResults<Shot>
    @FetchRequest private var teams: FetchedResults<Team>

    init(game: Game) {
        self.game = game

        let shotsPredicate = NSPredicate(format: "gameId == %@", game.id! as CVarArg)
        _shots = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Shot.timestamp, ascending: true)],
            predicate: shotsPredicate
        )

        if let teamId = game.teamId {
            let teamPredicate = NSPredicate(format: "id == %@", teamId as CVarArg)
            _teams = FetchRequest(
                sortDescriptors: [],
                predicate: teamPredicate
            )
        } else {
            _teams = FetchRequest(
                sortDescriptors: [],
                predicate: NSPredicate(value: false)
            )
        }
    }

    private var team: Team? {
        teams.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Stats View", selection: $selectedTab) {
                Text("Game").tag(0)
                Text("By Player").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            ScrollView {
                if selectedTab == 0 {
                    GameStatsView(shots: Array(shots))
                } else {
                    PlayerStatsView(shots: Array(shots), teamId: game.teamId)
                }
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

struct GameStatsView: View {
    let shots: [Shot]

    private var firstHalfShots: [Shot] {
        shots.filter { $0.quarter == 1 || $0.quarter == 2 }
    }

    private var secondHalfShots: [Shot] {
        shots.filter { $0.quarter == 3 || $0.quarter == 4 }
    }

    var body: some View {
        if shots.isEmpty {
            Text("No shots recorded")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding()
        } else {
            VStack(spacing: 12) {
                // Header row
                HStack(spacing: 0) {
                    Text("Period")
                        .frame(width: 90, alignment: .leading)
                    Text("2Pa")
                        .frame(width: 44)
                    Text("2Pm")
                        .frame(width: 44)
                    Text("3Pa")
                        .frame(width: 44)
                    Text("3Pm")
                        .frame(width: 44)
                    Text("FTa")
                        .frame(width: 44)
                    Text("FTm")
                        .frame(width: 44)
                    Text("FGa")
                        .frame(width: 44)
                    Text("FGm")
                        .frame(width: 44)
                    Text("FG%")
                        .frame(width: 54)
                    Text("eFG%")
                        .frame(width: 54)
                }
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .padding(.horizontal)

                Divider()

                // Period rows
                PeriodStatsRow(label: "1st Half", stats: PlayerStats(shots: firstHalfShots))
                PeriodStatsRow(label: "2nd Half", stats: PlayerStats(shots: secondHalfShots))

                Divider()

                PeriodStatsRow(label: "Full Game", stats: PlayerStats(shots: shots), isTotal: true)
            }
            .padding(.horizontal)
        }
    }
}

struct PeriodStatsRow: View {
    let label: String
    let stats: PlayerStats
    var isTotal: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(isTotal ? .body.bold() : .body)
                .frame(width: 90, alignment: .leading)

            Text("\(stats.twoPointAttempts)")
                .frame(width: 44)
            Text("\(stats.twoPointMade)")
                .frame(width: 44)
            Text("\(stats.threePointAttempts)")
                .frame(width: 44)
            Text("\(stats.threePointMade)")
                .frame(width: 44)
            Text("\(stats.freeThrowAttempts)")
                .frame(width: 44)
            Text("\(stats.freeThrowMade)")
                .frame(width: 44)
            Text("\(stats.fieldGoalAttempts)")
                .frame(width: 44)
            Text("\(stats.fieldGoalMade)")
                .frame(width: 44)
            Text(String(format: "%.0f", stats.fieldGoalPercentage))
                .frame(width: 54)
                .foregroundColor(percentageColor(stats.fieldGoalPercentage))
            Text(String(format: "%.0f", stats.effectiveFieldGoalPercentage))
                .frame(width: 54)
                .foregroundColor(percentageColor(stats.effectiveFieldGoalPercentage))
        }
        .font(isTotal ? .body.bold() : .body)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isTotal ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    private func percentageColor(_ percentage: Double) -> Color {
        if percentage >= 50 { return .green }
        if percentage >= 33 { return .orange }
        return .red
    }
}

struct PlayerStatsView: View {
    let shots: [Shot]
    let teamId: UUID?

    @FetchRequest private var players: FetchedResults<Player>

    init(shots: [Shot], teamId: UUID?) {
        self.shots = shots
        self.teamId = teamId

        if let teamId = teamId {
            let predicate = NSPredicate(format: "teamId == %@", teamId as CVarArg)
            _players = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \Player.number, ascending: true)],
                predicate: predicate
            )
        } else {
            _players = FetchRequest(
                sortDescriptors: [],
                predicate: NSPredicate(value: false)
            )
        }
    }

    private var playerNumbers: [Int16] {
        var numbers = Set(shots.map { $0.playerNumber })
        numbers.remove(0)  // Handle unassigned separately
        return numbers.sorted()
    }

    private func playerName(for number: Int16) -> String? {
        guard let player = players.first(where: { $0.number == number }) else {
            return nil
        }
        return player.name
    }

    private func stats(for playerNumber: Int16) -> PlayerStats {
        let playerShots = shots.filter { $0.playerNumber == playerNumber }
        return PlayerStats(shots: playerShots)
    }

    var body: some View {
        if playerNumbers.isEmpty && shots.filter({ $0.playerNumber == 0 }).isEmpty {
            Text("No shots recorded")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding()
        } else {
            VStack(spacing: 12) {
                // Header row
                HStack(spacing: 0) {
                    Text("#")
                        .frame(width: 50, alignment: .leading)
                    Text("2Pa")
                        .frame(width: 44)
                    Text("2Pm")
                        .frame(width: 44)
                    Text("3Pa")
                        .frame(width: 44)
                    Text("3Pm")
                        .frame(width: 44)
                    Text("FTa")
                        .frame(width: 44)
                    Text("FTm")
                        .frame(width: 44)
                    Text("FGa")
                        .frame(width: 44)
                    Text("FGm")
                        .frame(width: 44)
                    Text("FG%")
                        .frame(width: 54)
                    Text("eFG%")
                        .frame(width: 54)
                }
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .padding(.horizontal)

                Divider()

                // Player rows
                ForEach(playerNumbers, id: \.self) { number in
                    PlayerStatsRow(
                        number: number,
                        name: playerName(for: number),
                        stats: stats(for: number)
                    )
                }

                // Unassigned shots
                let unassignedShots = shots.filter { $0.playerNumber == 0 }
                if !unassignedShots.isEmpty {
                    PlayerStatsRow(
                        number: 0,
                        name: "--",
                        stats: PlayerStats(shots: unassignedShots)
                    )
                }

                Divider()

                // Totals row
                PlayerStatsRow(
                    number: -1,
                    name: "Total",
                    stats: PlayerStats(shots: shots),
                    isTotal: true
                )
            }
            .padding(.horizontal)
        }
    }
}

struct PlayerStats {
    let twoPointAttempts: Int
    let twoPointMade: Int
    let threePointAttempts: Int
    let threePointMade: Int
    let freeThrowAttempts: Int
    let freeThrowMade: Int

    var fieldGoalAttempts: Int { twoPointAttempts + threePointAttempts }
    var fieldGoalMade: Int { twoPointMade + threePointMade }

    var fieldGoalPercentage: Double {
        fieldGoalAttempts > 0 ? Double(fieldGoalMade) / Double(fieldGoalAttempts) * 100 : 0
    }

    // eFG% = (FGM + 0.5 * 3PM) / FGA
    var effectiveFieldGoalPercentage: Double {
        fieldGoalAttempts > 0 ? (Double(fieldGoalMade) + 0.5 * Double(threePointMade)) / Double(fieldGoalAttempts) * 100 : 0
    }

    init(shots: [Shot]) {
        let twos = shots.filter { $0.type == ShotType.twoPointer.rawValue }
        let threes = shots.filter { $0.type == ShotType.threePointer.rawValue }
        let freeThrows = shots.filter { $0.type == ShotType.freeThrow.rawValue }

        twoPointAttempts = twos.count
        twoPointMade = twos.filter { $0.made }.count
        threePointAttempts = threes.count
        threePointMade = threes.filter { $0.made }.count
        freeThrowAttempts = freeThrows.count
        freeThrowMade = freeThrows.filter { $0.made }.count
    }
}

struct PlayerStatsRow: View {
    let number: Int16
    let name: String?
    let stats: PlayerStats
    var isTotal: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Player identifier
            if isTotal {
                Text("Total")
                    .font(.body.bold())
                    .frame(width: 50, alignment: .leading)
            } else if number > 0 {
                Text("#\(number)")
                    .font(.body.bold())
                    .frame(width: 50, alignment: .leading)
            } else {
                Text("--")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
            }

            // Stats columns
            Text("\(stats.twoPointAttempts)")
                .frame(width: 44)
            Text("\(stats.twoPointMade)")
                .frame(width: 44)
            Text("\(stats.threePointAttempts)")
                .frame(width: 44)
            Text("\(stats.threePointMade)")
                .frame(width: 44)
            Text("\(stats.freeThrowAttempts)")
                .frame(width: 44)
            Text("\(stats.freeThrowMade)")
                .frame(width: 44)
            Text("\(stats.fieldGoalAttempts)")
                .frame(width: 44)
            Text("\(stats.fieldGoalMade)")
                .frame(width: 44)
            Text(String(format: "%.0f", stats.fieldGoalPercentage))
                .frame(width: 54)
                .foregroundColor(percentageColor(stats.fieldGoalPercentage))
            Text(String(format: "%.0f", stats.effectiveFieldGoalPercentage))
                .frame(width: 54)
                .foregroundColor(percentageColor(stats.effectiveFieldGoalPercentage))
        }
        .font(isTotal ? .body.bold() : .body)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isTotal ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }

    private func percentageColor(_ percentage: Double) -> Color {
        if percentage >= 50 { return .green }
        if percentage >= 33 { return .orange }
        return .red
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let game = Game(context: context)
    game.id = UUID()
    game.date = Date()

    // Add sample shots
    for i in 0..<10 {
        let shot = Shot(context: context)
        shot.id = UUID()
        shot.x = Double.random(in: 0.1...0.9)
        shot.y = Double.random(in: 0.3...0.9)
        shot.made = Bool.random()
        shot.type = Int16.random(in: 0...2)
        shot.quarter = Int16.random(in: 1...4)
        shot.playerNumber = [1, 5, 23][i % 3]
        shot.timestamp = Date()
        shot.gameId = game.id
    }

    return NavigationStack {
        StatsView(game: game)
    }
    .environment(\.managedObjectContext, context)
}
