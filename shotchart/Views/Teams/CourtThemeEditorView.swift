import SwiftUI

// MARK: - Court Theme Editor View (Compact Button + Thumbnail)

struct CourtThemeEditorView: View {
    @ObservedObject var team: Team
    var onOpenSettings: (() -> Void)? = nil
    @State private var showingThemePopup = false
    @AppStorage("courtType") private var defaultCourtTypeRaw = CourtType.highSchool.rawValue

    private var currentTheme: CourtTheme {
        CourtTheme(from: team)
    }

    private var effectiveCourtType: CourtType {
        if let teamType = team.courtType, let type = CourtType(rawValue: teamType) {
            return type
        }
        return CourtType(rawValue: defaultCourtTypeRaw) ?? .highSchool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Checkbox to enable custom theme
            Button(action: {
                team.useCustomCourtTheme.toggle()
                if team.useCustomCourtTheme {
                    // If enabling and no theme data exists, set defaults and open editor
                    if !currentTheme.hasCustomBackground && currentTheme.lineColor == .white {
                        team.setPattern(.horizontalGradient)
                        showingThemePopup = true
                    }
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: team.useCustomCourtTheme ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundColor(team.useCustomCourtTheme ? DS.actionEdit : DS.textSecondary)

                    Text("Use custom court theme")
                        .font(.headline)
                        .foregroundColor(DS.textPrimary)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            // Show theme editor button only when custom theme is enabled
            if team.useCustomCourtTheme {
                Button(action: { showingThemePopup = true }) {
                    HStack(spacing: 12) {
                        // Thumbnail preview
                        CourtThemeThumbnail(theme: currentTheme, courtType: effectiveCourtType)
                            .frame(width: 80, height: 75)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentTheme.pattern.displayName)
                                .font(.subheadline.bold())
                                .foregroundColor(DS.textPrimary)
                            if currentTheme.backgroundColors.isEmpty {
                                Text("Line color only")
                                    .font(.caption)
                                    .foregroundColor(DS.textSecondary)
                            } else {
                                Text("\(currentTheme.backgroundColors.count) color\(currentTheme.backgroundColors.count == 1 ? "" : "s"), \(Int(currentTheme.backgroundAlpha * 100))% opacity")
                                    .font(.caption)
                                    .foregroundColor(DS.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundColor(DS.iconChevron)
                    }
                    .padding(12)
                    .background(DS.cardBackground)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingThemePopup) {
            CourtThemeEditorPopup(team: team, isPresented: $showingThemePopup, courtType: effectiveCourtType, onOpenSettings: {
                showingThemePopup = false
                onOpenSettings?()
            })
        }
    }
}

// MARK: - Court Theme Thumbnail

struct CourtThemeThumbnail: View {
    let theme: CourtTheme
    var courtType: CourtType = .highSchool

    var body: some View {
        // Use the actual CourtView at a larger size, then scale it down
        CourtView(
            shots: [],
            theme: theme.hasCustomBackground ? theme : nil,
            teamCourtType: courtType.rawValue
        ) { _, _ in }
            .frame(width: 400, height: 375)
            .scaleEffect(0.2)
            .frame(width: 80, height: 75)
            .clipped()
    }
}

// MARK: - Court Theme Editor Popup

struct CourtThemeEditorPopup: View {
    @ObservedObject var team: Team
    @Binding var isPresented: Bool
    var courtType: CourtType = .highSchool
    var onOpenSettings: (() -> Void)? = nil

    @AppStorage("useTeamColors") private var useTeamColors = true

    @State private var backgroundColors: [Color] = []
    @State private var backgroundAlpha: Float = 1.0
    @State private var patternScale: Float = 1.0
    @State private var lineColorOption: LineColorOption = .white
    @State private var customLineColor: Color = .white
    @State private var selectedPattern: CourtBackgroundPattern = .solid

    // Track original values to detect changes
    @State private var originalColors: [Color] = []
    @State private var originalAlpha: Float = 1.0
    @State private var originalScale: Float = 1.0
    @State private var originalLineOption: LineColorOption = .white
    @State private var originalCustomLineColor: Color = .white
    @State private var originalPattern: CourtBackgroundPattern = .solid

    @State private var showingDiscardAlert = false

    enum LineColorOption: String, CaseIterable {
        case white = "White"
        case black = "Black"
        case custom = "Custom"
    }

    private var currentTheme: CourtTheme {
        CourtTheme(
            backgroundColors: backgroundColors,
            backgroundAlpha: backgroundAlpha,
            lineColor: currentLineColor,
            pattern: selectedPattern,
            patternScale: patternScale
        )
    }

    private var currentLineColor: CourtLineColor {
        switch lineColorOption {
        case .white: return .white
        case .black: return .black
        case .custom: return .custom(customLineColor)
        }
    }

    private var hasUnsavedChanges: Bool {
        backgroundColors != originalColors ||
        backgroundAlpha != originalAlpha ||
        patternScale != originalScale ||
        lineColorOption != originalLineOption ||
        customLineColor != originalCustomLineColor ||
        selectedPattern != originalPattern
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning if team colors are disabled in settings
                    if !useTeamColors {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Team colors are disabled")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.red)
                                Text("These colors won't show during games until enabled in Settings.")
                                    .font(.caption)
                                    .foregroundColor(DS.textSecondary)
                            }

                            Spacer()

                            if onOpenSettings != nil {
                                Button("Settings") {
                                    onOpenSettings?()
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(6)
                            }
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }

                    // Preview with Line Color beside it
                    HStack(alignment: .top, spacing: 16) {
                        // Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.headline)
                                .foregroundColor(DS.textPrimary)

                            CourtView(
                                shots: [],
                                theme: backgroundColors.isEmpty ? nil : currentTheme,
                                teamCourtType: courtType.rawValue
                            ) { _, _ in }
                                .frame(width: 240, height: 225)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }

                        // Line Color (show if we have colors or if "none" pattern selected for line-only mode)
                        if !backgroundColors.isEmpty || selectedPattern == .none {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Line Color")
                                    .font(.headline)
                                    .foregroundColor(DS.textPrimary)

                                ForEach(LineColorOption.allCases, id: \.self) { option in
                                    Button(action: {
                                        lineColorOption = option
                                    }) {
                                        HStack(spacing: 8) {
                                            if option == .custom {
                                                ColorPicker("", selection: $customLineColor, supportsOpacity: false)
                                                    .labelsHidden()
                                                    .frame(width: 24, height: 24)
                                            } else {
                                                Circle()
                                                    .fill(option == .white ? Color.white : Color.black)
                                                    .frame(width: 24, height: 24)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                                                    )
                                            }
                                            Text(option.rawValue)
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(lineColorOption == option ? DS.cardBackgroundSelected : DS.cardBackground)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    // Opacity Slider (right under preview, not for "none" pattern)
                    if !backgroundColors.isEmpty && selectedPattern != .none {
                        HStack(spacing: 12) {
                            Text("Opacity")
                                .font(.subheadline)
                                .foregroundColor(DS.textSecondary)
                            Slider(value: $backgroundAlpha, in: 0.1...1.0, step: 0.05)
                            Text("\(Int(backgroundAlpha * 100))%")
                                .font(.subheadline)
                                .foregroundColor(DS.textSecondary)
                                .frame(width: 40)
                        }
                    }

                    // Colors (hidden when "none" pattern is selected)
                    if selectedPattern != .none {
                        VStack(alignment: .leading, spacing: 12) {
                            // Warning for Shot Zones needing 6 colors
                            if selectedPattern == .zonesBased && backgroundColors.count < 6 {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.subheadline)
                                    Text("Shot Zones works best with 6 distinct colors for all zones")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            }

                            HStack {
                                Text("Colors")
                                    .font(.headline)
                                    .foregroundColor(DS.textPrimary)

                                Spacer()

                                if !backgroundColors.isEmpty {
                                    Button("Clear All") {
                                        backgroundColors = []
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(DS.actionDestructive)
                                }
                            }

                            Text("Add \(selectedPattern.minColors)-\(selectedPattern.maxColors) colors for this pattern")
                                .font(.caption)
                                .foregroundColor(DS.textSecondary)

                            HStack(spacing: 12) {
                                ForEach(0..<backgroundColors.count, id: \.self) { index in
                                    ColorPickerSquare(
                                        color: $backgroundColors[index],
                                        onDelete: {
                                            if backgroundColors.count > selectedPattern.minColors || backgroundColors.count > 1 {
                                                backgroundColors.remove(at: index)
                                            }
                                        },
                                        onChange: { }
                                    )
                                }

                                if backgroundColors.count < selectedPattern.maxColors {
                                    AddColorButton(onColorAdded: { color in
                                        backgroundColors.append(color)
                                    })
                                }

                                Spacer()
                            }
                        }
                    }

                    // Pattern Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pattern")
                            .font(.headline)
                            .foregroundColor(DS.textPrimary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(CourtBackgroundPattern.allCases) { pattern in
                                PatternOptionView(
                                    pattern: pattern,
                                    colors: backgroundColors.isEmpty ? [Color.gray.opacity(0.6), Color.gray.opacity(0.3), Color.gray.opacity(0.45)] : backgroundColors,
                                    patternScale: patternScale,
                                    isSelected: selectedPattern == pattern,
                                    onSelect: {
                                        selectedPattern = pattern
                                        if pattern == .none {
                                            // Clear colors when "none" is selected (line colors only mode)
                                            backgroundColors = []
                                        } else if backgroundColors.count < pattern.minColors {
                                            // Auto-add placeholder colors if needed (user can change them)
                                            let placeholderColors: [Color] = [.gray.opacity(0.5), .gray.opacity(0.3), .gray.opacity(0.7), .gray.opacity(0.4)]
                                            while backgroundColors.count < pattern.minColors {
                                                backgroundColors.append(placeholderColors[backgroundColors.count % placeholderColors.count])
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }

                    // Pattern Scale (only for patterns that support it)
                    if !backgroundColors.isEmpty && selectedPattern.supportsScale {
                        HStack(spacing: 12) {
                            Text("Scale")
                                .font(.subheadline)
                                .foregroundColor(DS.textSecondary)
                            Slider(value: $patternScale, in: 0.5...4.0, step: 0.5)
                            Text(String(format: "%.1fx", patternScale))
                                .font(.subheadline)
                                .foregroundColor(DS.textSecondary)
                                .frame(width: 40)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
            .background(DS.popupBackground)
            .navigationTitle("Court Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingDiscardAlert = true
                        } else {
                            isPresented = false
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTheme()
                        isPresented = false
                    }
                    .font(.headline)
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    isPresented = false
                }
            } message: {
                Text("You have unsaved changes that will be lost.")
            }
        }
        .onAppear {
            loadTheme()
        }
    }

    private func loadTheme() {
        backgroundColors = team.getBackgroundColors()
        backgroundAlpha = team.courtBackgroundAlpha > 0 ? team.courtBackgroundAlpha : 1.0
        patternScale = team.courtPatternScale > 0 ? team.courtPatternScale : 1.0
        selectedPattern = team.getPattern()

        let lineColor = team.getLineColor()
        switch lineColor {
        case .white:
            lineColorOption = .white
        case .black:
            lineColorOption = .black
        case .custom(let color):
            lineColorOption = .custom
            customLineColor = color
        }

        // Save original values to detect changes
        originalColors = backgroundColors
        originalAlpha = backgroundAlpha
        originalScale = patternScale
        originalPattern = selectedPattern
        originalLineOption = lineColorOption
        originalCustomLineColor = customLineColor
    }

    private func saveTheme() {
        team.setBackgroundColors(backgroundColors)
        team.courtBackgroundAlpha = backgroundAlpha
        team.courtPatternScale = patternScale
        team.setLineColor(currentLineColor)
        team.setPattern(selectedPattern)
    }
}

// MARK: - Pattern Option View

struct PatternOptionView: View {
    let pattern: CourtBackgroundPattern
    let colors: [Color]
    let patternScale: Float
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                // Pattern thumbnail
                if pattern == .none {
                    // Show dashed rectangle for "none" pattern
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundColor(Color.gray.opacity(0.5))
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )
                } else {
                    CourtBackgroundView(colors: colors, alpha: 1.0, pattern: pattern, patternScale: patternScale)
                        .frame(height: 50)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                        )
                }

                Text(pattern.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .blue : DS.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(6)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Color Button

struct AddColorButton: View {
    let onColorAdded: (Color) -> Void
    @State private var selectedColor: Color = .blue
    @State private var hasSelectedColor = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                .frame(width: 50, height: 50)

            Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(.gray)

            // Invisible ColorPicker overlay - tapping opens system picker directly
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .opacity(0.02) // Nearly invisible but still tappable
                .frame(width: 50, height: 50)
        }
        .onChange(of: selectedColor) { _, newColor in
            // Add the color when user picks one
            if hasSelectedColor {
                onColorAdded(newColor)
            }
            hasSelectedColor = true
        }
    }
}

// MARK: - Color Picker Square

struct ColorPickerSquare: View {
    @Binding var color: Color
    let onDelete: () -> Void
    let onChange: () -> Void

    @State private var showingPicker = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 44, height: 44)
                .onChange(of: color) { _, _ in
                    onChange()
                }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
                    .background(Circle().fill(Color.white).frame(width: 14, height: 14))
            }
            .offset(x: 6, y: -6)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let team = Team(context: context)
    team.id = UUID()
    team.name = "Test Team"
    team.courtBackgroundColor = "#0000FF,#FF0000"
    team.courtBackgroundAlpha = 0.8
    team.courtLineColor = "white"

    return VStack {
        CourtThemeEditorView(team: team)
            .padding()
    }
    .background(Color(.systemBackground))
}
