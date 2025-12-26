import SwiftUI
import CoreData

struct PlayerSelectorView: View {
    @Environment(\.managedObjectContext) private var viewContext

    let team: Team?
    let teamPlayers: [Player]
    @Binding var selectedPlayerNumber: Int16?
    @Binding var gameRoster: Set<Int16>

    @State private var showingAddPlayer = false
    @State private var newPlayerNumber = ""

    private var availablePlayers: [Int16] {
        if team != nil {
            return teamPlayers.map { $0.number }.sorted()
        } else {
            return Array(gameRoster).sorted()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Player")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availablePlayers, id: \.self) { number in
                        PlayerNumberButton(
                            number: number,
                            isSelected: selectedPlayerNumber == number
                        ) {
                            if selectedPlayerNumber == number {
                                selectedPlayerNumber = nil
                            } else {
                                selectedPlayerNumber = number
                            }
                        }
                    }

                    Button(action: { showingAddPlayer = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .alert("Add Player", isPresented: $showingAddPlayer) {
            TextField("Jersey Number", text: $newPlayerNumber)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {
                newPlayerNumber = ""
            }
            Button("Add") {
                addPlayer()
            }
        } message: {
            Text("Enter the player's jersey number")
        }
    }

    private func addPlayer() {
        guard let number = Int16(newPlayerNumber) else {
            newPlayerNumber = ""
            return
        }

        if let team = team {
            // Add to team roster permanently
            if !teamPlayers.contains(where: { $0.number == number }) {
                let player = Player(context: viewContext)
                player.id = UUID()
                player.number = number
                player.teamId = team.id
                player.createdAt = Date()

                do {
                    try viewContext.save()
                } catch {
                    print("Error adding player: \(error)")
                }
            }
        } else {
            // Add to game-only roster
            gameRoster.insert(number)
        }

        selectedPlayerNumber = number
        newPlayerNumber = ""
    }
}

struct PlayerNumberButton: View {
    let number: Int16
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("#\(number)")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

#Preview {
    PlayerSelectorView(
        team: nil,
        teamPlayers: [],
        selectedPlayerNumber: .constant(23),
        gameRoster: .constant([1, 5, 10, 23, 33])
    )
    .padding()
}
