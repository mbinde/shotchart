import SwiftUI
import CoreData

struct ShotEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var shot: Shot

    let team: Team?
    let teamPlayers: [Player]
    let gameRoster: Set<Int16>
    let onDelete: () -> Void
    let onRelocate: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var newPlayerNumber = ""
    @State private var showingAddPlayer = false

    private var availablePlayers: [Int16] {
        if team != nil {
            return teamPlayers.map { $0.number }.sorted()
        } else {
            return Array(gameRoster).sorted()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Result") {
                    Picker("Result", selection: Binding(
                        get: { shot.made },
                        set: { shot.made = $0; save() }
                    )) {
                        Text("Made").tag(true)
                        Text("Missed").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Shot Type") {
                    Picker("Type", selection: Binding(
                        get: { ShotType(rawValue: shot.type) ?? .twoPointer },
                        set: { shot.type = $0.rawValue; save() }
                    )) {
                        ForEach(ShotType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Layup", isOn: Binding(
                        get: { shot.isLayup },
                        set: { shot.isLayup = $0; save() }
                    ))
                }

                Section("Player") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availablePlayers, id: \.self) { number in
                                Button(action: {
                                    shot.playerNumber = number
                                    // Look up player to set playerId
                                    if let player = teamPlayers.first(where: { $0.number == number }) {
                                        shot.playerId = player.id
                                    }
                                    save()
                                }) {
                                    Text("#\(number)")
                                        .font(.headline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(shot.playerNumber == number ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(shot.playerNumber == number ? .white : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }

                            Button(action: { showingAddPlayer = true }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Section("Quarter") {
                    Picker("Quarter", selection: Binding(
                        get: { shot.quarter },
                        set: { shot.quarter = $0; save() }
                    )) {
                        ForEach(1...4, id: \.self) { q in
                            Text("Q\(q)").tag(Int16(q))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(action: {
                        dismiss()
                        onRelocate()
                    }) {
                        Label("Move Shot Location", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    }

                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Shot", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Shot?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    dismiss()
                    onDelete()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .alert("Add Player", isPresented: $showingAddPlayer) {
                TextField("Jersey Number", text: $newPlayerNumber)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) { newPlayerNumber = "" }
                Button("Add") {
                    if let number = Int16(newPlayerNumber) {
                        shot.playerNumber = number
                        save()
                    }
                    newPlayerNumber = ""
                }
            }
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
