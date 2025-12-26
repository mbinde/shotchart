import SwiftUI
import CoreData

struct GameSetupView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        animation: .default)
    private var teams: FetchedResults<Team>

    @State private var selectedTeam: Team?
    @State private var navigateToGame = false
    @State private var newGame: Game?

    private static let lastTeamKey = "lastSelectedTeamID"

    var body: some View {
        Form {
            Section("Select Team (Optional)") {
                Picker("Team", selection: $selectedTeam) {
                    Text("No Team").tag(nil as Team?)
                    ForEach(teams) { team in
                        Text(team.name ?? "Unnamed").tag(team as Team?)
                    }
                }
            }

            Section {
                Button(action: startGame) {
                    HStack {
                        Spacer()
                        Label("Start Game", systemImage: "sportscourt")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("New Game")
        .navigationDestination(isPresented: $navigateToGame) {
            if let game = newGame {
                GameView(game: game)
            }
        }
        .onAppear {
            loadLastTeam()
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

        // Update lastSeenAt for all players on this team
        if let teamId = selectedTeam?.id {
            updateLastSeenForTeam(teamId: teamId, date: game.date ?? Date())
        }

        do {
            try viewContext.save()
            newGame = game
            navigateToGame = true
        } catch {
            print("Error creating game: \(error)")
        }
    }

    private func updateLastSeenForTeam(teamId: UUID, date: Date) {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "teamId == %@ AND archivedAt == nil", teamId as CVarArg)

        if let players = try? viewContext.fetch(request) {
            for player in players {
                if player.lastSeenAt == nil || date > player.lastSeenAt! {
                    player.lastSeenAt = date
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GameSetupView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
