import SwiftUI
import CoreData

struct TeamListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Team.name, ascending: true)],
        animation: .default)
    private var teams: FetchedResults<Team>

    @State private var showingAddTeam = false
    @State private var editingTeam: Team?

    var body: some View {
        ZStack {
            List {
                ForEach(teams) { team in
                    Button(action: { editingTeam = team }) {
                        TeamListRowView(team: team)
                    }
                    .foregroundColor(.primary)
                }
                .onDelete(perform: deleteTeams)
            }
            .navigationTitle("Teams")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTeam = true }) {
                        Label("Add Team", systemImage: "plus")
                    }
                }
            }

            // Add team popup
            if showingAddTeam {
                AddTeamPopup(
                    onSave: { showingAddTeam = false },
                    onCancel: { showingAddTeam = false }
                )
            }

            // Edit team popup
            if let team = editingTeam {
                TeamEditorPopupWrapper(
                    team: team,
                    onSave: {
                        saveContext()
                        editingTeam = nil
                    },
                    onCancel: {
                        viewContext.rollback()
                        editingTeam = nil
                    }
                )
            }
        }
    }

    private func deleteTeams(offsets: IndexSet) {
        offsets.map { teams[$0] }.forEach(viewContext.delete)
        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving: \(error)")
        }
    }
}

struct AddTeamPopup: View {
    @Environment(\.managedObjectContext) private var viewContext
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var teamName = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 24) {
                Text("New Team")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: 8) {
                    Text("Team Name")
                        .font(.headline)
                        .foregroundColor(DS.textPrimary)
                    TextField("Enter team name", text: $teamName)
                        .font(.title3)
                        .padding()
                        .background(DS.cardBackground)
                        .cornerRadius(10)
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

                    Button("Create") {
                        createTeam()
                        onSave()
                    }
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(teamName.isEmpty ? Color.gray : DS.actionPrimary)
                    .cornerRadius(12)
                    .disabled(teamName.isEmpty)
                }
            }
            .padding(24)
            .background(DS.popupBackground)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
        }
    }

    private func createTeam() {
        guard !teamName.isEmpty else { return }

        let team = Team(context: viewContext)
        team.id = UUID()
        team.name = teamName
        team.createdAt = Date()

        do {
            try viewContext.save()
        } catch {
            print("Error creating team: \(error)")
        }
    }
}

struct TeamListRowView: View {
    let team: Team

    @FetchRequest private var players: FetchedResults<Player>

    init(team: Team) {
        self.team = team

        let predicate = NSPredicate(format: "teamId == %@ AND archivedAt == nil", team.id! as CVarArg)
        _players = FetchRequest(
            sortDescriptors: [],
            predicate: predicate
        )
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(team.name ?? "Unnamed Team")
                    .font(.headline)
                Text("\(players.count) player\(players.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(DS.iconChevron)
                .font(.caption)
        }
    }
}

#Preview {
    NavigationStack {
        TeamListView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
