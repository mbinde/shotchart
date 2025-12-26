import SwiftUI

struct SettingsPopup: View {
    let onClose: () -> Void
    @AppStorage("useWoodFloor") private var useWoodFloor = true
    @AppStorage("useTeamColors") private var useTeamColors = true
    @AppStorage("courtType") private var courtTypeRaw = CourtType.highSchool.rawValue

    // Trackable Items
    @AppStorage("showLayup") private var showLayup = true
    @AppStorage("showSteal") private var showSteal = true
    @AppStorage("showTurnover") private var showTurnover = true
    @AppStorage("showOffensiveRebound") private var showOffensiveRebound = true
    @AppStorage("showDefensiveRebound") private var showDefensiveRebound = true
    @AppStorage("showAssist") private var showAssist = true
    @AppStorage("showOffensiveFoul") private var showOffensiveFoul = true
    @AppStorage("showDefensiveFoul") private var showDefensiveFoul = true

    // Display
    @AppStorage("useAbbreviations") private var useAbbreviations = true

    // Game Options
    @AppStorage("showGameClock") private var showGameClock = false

    private var courtType: CourtType {
        get { CourtType(rawValue: courtTypeRaw) ?? .highSchool }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
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
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 24) {
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

                            SettingsCheckbox(
                                label: "Use team colors if available",
                                isOn: $useTeamColors
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Display
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Display")
                                .font(.headline)
                                .foregroundColor(DS.textSecondary)

                            SettingsToggleRow(
                                label: "Use Abbreviations",
                                isOn: $useAbbreviations
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Game Options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Game Options")
                                .font(.headline)
                                .foregroundColor(DS.textSecondary)

                            SettingsToggleRow(
                                label: "Show Game Clock",
                                isOn: $showGameClock
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Trackable Items
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trackable Items")
                                .font(.headline)
                                .foregroundColor(DS.textSecondary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                SettingsCheckbox(
                                    label: useAbbreviations ? "LA" : "Layup",
                                    isOn: $showLayup
                                )
                                SettingsCheckbox(
                                    label: useAbbreviations ? "STL" : "Steal",
                                    isOn: $showSteal
                                )
                                SettingsCheckbox(
                                    label: useAbbreviations ? "TO" : "Turnover",
                                    isOn: $showTurnover
                                )
                                SettingsCheckbox(
                                    label: useAbbreviations ? "AST" : "Assist",
                                    isOn: $showAssist
                                )
                                SettingsCheckbox(
                                    label: useAbbreviations ? "ORB" : "Off. Rebound",
                                    isOn: $showOffensiveRebound
                                )
                                SettingsCheckbox(
                                    label: useAbbreviations ? "DRB" : "Def. Rebound",
                                    isOn: $showDefensiveRebound
                                )
                                SettingsCheckbox(
                                    label: useAbbreviations ? "OF" : "Off. Foul",
                                    isOn: $showOffensiveFoul
                                )
                                SettingsCheckbox(
                                    label: useAbbreviations ? "DF" : "Def. Foul",
                                    isOn: $showDefensiveFoul
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                    }
                }

                Button("Done") {
                    onClose()
                }
                .font(.title3.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(DS.actionEdit)
                .cornerRadius(12)
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

struct SettingsToggleRow: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(DS.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Color.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SettingsCheckbox: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isOn ? .blue : DS.textSecondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(DS.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
