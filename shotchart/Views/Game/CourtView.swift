import SwiftUI

enum CourtType: String, CaseIterable {
    case highSchool = "highSchool"
    case college = "college"
    case nba = "nba"

    var displayName: String {
        switch self {
        case .highSchool: return "High School"
        case .college: return "College"
        case .nba: return "NBA"
        }
    }

    // Court dimensions in feet
    var keyWidth: CGFloat {
        switch self {
        case .highSchool, .college: return 12
        case .nba: return 16
        }
    }

    var threePointArc: CGFloat {
        switch self {
        case .highSchool: return 19.75
        case .college: return 22.146
        case .nba: return 23.75
        }
    }

    var threePointCorner: CGFloat {
        // Distance from sideline for corner 3s
        switch self {
        case .highSchool, .college: return 3
        case .nba: return 3
        }
    }

    var threePointCornerDistance: CGFloat {
        // Distance from basket to corner 3-point line
        // NBA: 22 feet, College: ~21.65 feet, High School: same as arc (no truncation)
        switch self {
        case .highSchool: return 19.75  // Same as arc - uniform distance
        case .college: return 21.65     // Truncated at corners
        case .nba: return 22.0          // Truncated at corners
        }
    }

    var freeThrowLineDistance: CGFloat {
        // Distance from baseline to free throw line
        return 19  // Same for all levels
    }

    var basketDistance: CGFloat {
        // Distance from baseline to center of basket
        return 5.25  // ~63 inches, same for all levels
    }
}

struct CourtView: View {
    let shots: [Shot]
    var relocatingShot: Shot? = nil
    var theme: CourtTheme? = nil
    var teamCourtType: String? = nil
    let onTap: (CGPoint, Bool) -> Void
    @AppStorage("useWoodFloor") private var useWoodFloor = true
    @AppStorage("useTeamColors") private var useTeamColors = true
    @AppStorage("courtType") private var courtTypeRaw = CourtType.highSchool.rawValue

    private var courtType: CourtType {
        // Use team's court type if set, otherwise fall back to settings default
        if let teamType = teamCourtType, let type = CourtType(rawValue: teamType) {
            return type
        }
        return CourtType(rawValue: courtTypeRaw) ?? .highSchool
    }

    /// Determine whether to use custom theme background
    private var useCustomBackground: Bool {
        useTeamColors && theme?.hasCustomBackground == true
    }

    /// Determine the line color to use
    private var effectiveLineColor: Color {
        if useTeamColors, let theme = theme, theme.hasCustomBackground {
            return theme.lineColor.color
        }
        return useWoodFloor ? .white : .black
    }

    var body: some View {
        GeometryReader { geometry in
            let courtSize = calculateCourtSize(in: geometry.size)

            ZStack {
                // Court background
                if useCustomBackground, let theme = theme {
                    // White base layer when opacity < 100% so colors blend with white, not wood/beige
                    if theme.backgroundAlpha < 1.0 {
                        Rectangle().fill(Color.white)
                    }
                    // Custom team theme background
                    CourtBackgroundView(colors: theme.backgroundColors, alpha: theme.backgroundAlpha, pattern: theme.pattern, patternScale: theme.patternScale, courtType: courtType)
                } else if useWoodFloor {
                    Image("wood-floor")
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.87, blue: 0.75))
                }

                // Court lines - explicit frame to ensure correct size
                Canvas { context, size in
                    drawCourt(context: context, size: size, lineColor: effectiveLineColor, courtType: courtType)
                }
                .frame(width: courtSize.width, height: courtSize.height)

                // Shot markers
                ForEach(shots, id: \.id) { shot in
                    ShotMarker(shot: shot, isRelocating: shot.id == relocatingShot?.id)
                        .position(
                            x: shot.x * courtSize.width,
                            y: shot.y * courtSize.height
                        )
                }
            }
            .frame(width: courtSize.width, height: courtSize.height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                onTap(CGPoint(x: location.x / courtSize.width, y: location.y / courtSize.height), true)
            }
            .onTapGesture(count: 1) { location in
                onTap(CGPoint(x: location.x / courtSize.width, y: location.y / courtSize.height), false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func calculateCourtSize(in size: CGSize) -> CGSize {
        let courtAspect: CGFloat = 50.0 / 47.0
        let viewAspect = size.width / size.height

        if viewAspect > courtAspect {
            let height = size.height
            return CGSize(width: height * courtAspect, height: height)
        } else {
            let width = size.width
            return CGSize(width: width, height: width / courtAspect)
        }
    }

    private func drawCourt(context: GraphicsContext, size: CGSize, lineColor: Color, courtType: CourtType) {
        let w = size.width
        let h = size.height

        // Helper to convert feet to pixels (court is 50' x 47')
        func x(_ feet: CGFloat) -> CGFloat { feet / 50.0 * w }
        func y(_ feet: CGFloat) -> CGFloat { feet / 47.0 * h }

        var path = Path()

        // Outer boundary
        path.addRect(CGRect(x: 0, y: 0, width: w, height: h))

        // Key/Paint - width varies by court type
        let keyWidthFeet = courtType.keyWidth
        let keyLeft = x((50 - keyWidthFeet) / 2)
        let keyRight = x((50 + keyWidthFeet) / 2)
        let keyBottom = y(courtType.freeThrowLineDistance)
        path.addRect(CGRect(x: keyLeft, y: 0, width: x(keyWidthFeet), height: keyBottom))

        // Backboard (6' wide, just behind the rim)
        let basketY = courtType.basketDistance
        let backboardY = basketY - 1.25  // Backboard is about 1.25' behind rim center
        path.move(to: CGPoint(x: x(22), y: y(backboardY)))
        path.addLine(to: CGPoint(x: x(28), y: y(backboardY)))

        // Rim (1.5' diameter)
        let rimCenterX = x(25)
        let rimCenterY = y(basketY)
        let rimRadius = x(0.75)
        path.addEllipse(in: CGRect(x: rimCenterX - rimRadius, y: rimCenterY - rimRadius,
                                    width: rimRadius * 2, height: rimRadius * 2))

        // Free throw circle (6' radius = 12' diameter)
        let ftRadius = x(6)
        path.move(to: CGPoint(x: x((50 - 12) / 2), y: keyBottom))
        path.addArc(center: CGPoint(x: x(25), y: keyBottom),
                    radius: ftRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: true)

        // Lane hash marks - positions vary slightly by court type
        let hashLen = x(0.7)
        let hashPositions: [CGFloat] = [7, 11, 14, 17]
        for feet in hashPositions {
            let yPos = y(feet)
            path.move(to: CGPoint(x: keyLeft - hashLen, y: yPos))
            path.addLine(to: CGPoint(x: keyLeft, y: yPos))
            path.move(to: CGPoint(x: keyRight, y: yPos))
            path.addLine(to: CGPoint(x: keyRight + hashLen, y: yPos))
        }

        // Low block boxes
        let boxW = x(0.7)
        let boxH = y(0.7)
        path.addRect(CGRect(x: keyLeft - boxW, y: y(7), width: boxW, height: boxH))
        path.addRect(CGRect(x: keyRight, y: y(7), width: boxW, height: boxH))

        // 3-point line - varies by court type
        let corner3Feet = courtType.threePointCorner
        let arcRadiusFeet = courtType.threePointArc
        let basketFeetX: CGFloat = 25
        let basketFeetY = courtType.basketDistance

        let basketCenter = CGPoint(x: x(basketFeetX), y: y(basketFeetY))
        let arcRadiusPixels = x(arcRadiusFeet)

        // Check if arc reaches the corner lines (distance from basket to corner)
        let distanceToCorner = basketFeetX - corner3Feet  // ~22 feet

        if arcRadiusFeet >= distanceToCorner {
            // Arc reaches corners - draw corner lines + arc (NBA, College)
            let dxFeet = corner3Feet - basketFeetX
            let arcIntersectYFeet = basketFeetY + sqrt(arcRadiusFeet * arcRadiusFeet - dxFeet * dxFeet)

            let corner3X = x(corner3Feet)
            let arcIntersectY = y(arcIntersectYFeet)

            // Left corner (vertical line from baseline to arc intersection)
            path.move(to: CGPoint(x: corner3X, y: 0))
            path.addLine(to: CGPoint(x: corner3X, y: arcIntersectY))

            // 3-point arc (from left to right)
            let leftAngle = atan2(arcIntersectY - basketCenter.y, corner3X - basketCenter.x)
            let rightAngle = atan2(arcIntersectY - basketCenter.y, (w - corner3X) - basketCenter.x)

            path.addArc(center: basketCenter,
                        radius: arcRadiusPixels,
                        startAngle: Angle(radians: leftAngle),
                        endAngle: Angle(radians: rightAngle),
                        clockwise: true)

            // Right corner (vertical line from arc to baseline)
            path.addLine(to: CGPoint(x: w - corner3X, y: 0))
        } else {
            // Arc doesn't reach standard corners - draw corner lines at arc's max width (High School)
            // The arc's maximum width is at y = basketFeetY, extending ± arcRadiusFeet horizontally
            let leftCornerXFeet = basketFeetX - arcRadiusFeet
            let rightCornerXFeet = basketFeetX + arcRadiusFeet
            let cornerYFeet = basketFeetY

            let leftCornerX = x(leftCornerXFeet)
            let rightCornerX = x(rightCornerXFeet)
            let cornerY = y(cornerYFeet)

            // Left corner (vertical line from baseline to arc max-width point)
            path.move(to: CGPoint(x: leftCornerX, y: 0))
            path.addLine(to: CGPoint(x: leftCornerX, y: cornerY))

            // Arc from left to right (semicircle from max-width point around to other side)
            path.addArc(center: basketCenter,
                        radius: arcRadiusPixels,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: true)

            // Right corner (vertical line from arc to baseline)
            path.addLine(to: CGPoint(x: rightCornerX, y: 0))
        }

        // Center circle (6' radius, top half only at bottom of court)
        path.move(to: CGPoint(x: x(19), y: h))
        path.addArc(center: CGPoint(x: x(25), y: h),
                    radius: x(6),
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: true)

        context.stroke(path, with: .color(lineColor), lineWidth: 4)
    }
}

struct ShotMarker: View {
    @ObservedObject var shot: Shot
    var isRelocating: Bool = false

    var body: some View {
        ZStack {
            if shot.made {
                Circle()
                    .fill(isRelocating ? Color.gray.opacity(0.5) : Color.green)
                    .frame(width: 28, height: 28)
                Circle()
                    .stroke(isRelocating ? Color.gray : Color.white, lineWidth: 3)
                    .frame(width: 28, height: 28)
            } else {
                Circle()
                    .fill(isRelocating ? Color.gray.opacity(0.5) : Color.red)
                    .frame(width: 28, height: 28)
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isRelocating ? .gray : .white)
            }
        }
        .opacity(isRelocating ? 0.6 : 1.0)
    }
}

// MARK: - Court Background View

struct CourtBackgroundView: View {
    let colors: [Color]
    let alpha: Float
    let pattern: CourtBackgroundPattern
    let patternScale: Float
    let courtType: CourtType

    init(colors: [Color], alpha: Float, pattern: CourtBackgroundPattern = .verticalStripes, patternScale: Float = 1.0, courtType: CourtType = .highSchool) {
        self.colors = colors
        self.alpha = alpha
        self.pattern = pattern
        self.patternScale = patternScale
        self.courtType = courtType
    }

    private var effectiveColors: [Color] {
        colors.map { $0.opacity(Double(alpha)) }
    }

    var body: some View {
        GeometryReader { geometry in
            if colors.isEmpty {
                Rectangle()
                    .fill(Color(red: 0.93, green: 0.87, blue: 0.75))
            } else {
                patternView(size: geometry.size)
            }
        }
    }

    @ViewBuilder
    private func patternView(size: CGSize) -> some View {
        switch pattern {
        case .none:
            // No background - transparent
            Color.clear

        case .solid:
            Rectangle()
                .fill(effectiveColors.first ?? .clear)

        case .verticalStripes:
            Canvas { context, canvasSize in
                // Scale affects number of stripe repetitions (1.0 = one set, 2.0 = two sets, etc.)
                let repetitions = max(1, Int(CGFloat(patternScale) * 2))
                let totalStripes = effectiveColors.count * repetitions
                let stripeWidth = canvasSize.width / CGFloat(totalStripes)

                for i in 0..<totalStripes {
                    let colorIndex = i % effectiveColors.count
                    let rect = CGRect(x: CGFloat(i) * stripeWidth, y: 0, width: stripeWidth + 1, height: canvasSize.height)
                    context.fill(Path(rect), with: .color(effectiveColors[colorIndex]))
                }
            }

        case .horizontalStripes:
            Canvas { context, canvasSize in
                let repetitions = max(1, Int(CGFloat(patternScale) * 2))
                let totalStripes = effectiveColors.count * repetitions
                let stripeHeight = canvasSize.height / CGFloat(totalStripes)

                for i in 0..<totalStripes {
                    let colorIndex = i % effectiveColors.count
                    let rect = CGRect(x: 0, y: CGFloat(i) * stripeHeight, width: canvasSize.width, height: stripeHeight + 1)
                    context.fill(Path(rect), with: .color(effectiveColors[colorIndex]))
                }
            }

        case .diagonalStripes:
            Canvas { context, canvasSize in
                let repetitions = max(1, Int(CGFloat(patternScale) * 2))
                let totalStripes = effectiveColors.count * repetitions
                let stripeWidth = canvasSize.width / CGFloat(totalStripes)

                for i in 0..<totalStripes {
                    let colorIndex = i % effectiveColors.count
                    var path = Path()
                    let x = CGFloat(i) * stripeWidth
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
                    path.addLine(to: CGPoint(x: x + stripeWidth + canvasSize.height, y: canvasSize.height))
                    path.addLine(to: CGPoint(x: x + canvasSize.height, y: canvasSize.height))
                    path.closeSubpath()
                    context.fill(path, with: .color(effectiveColors[colorIndex]))
                }
                // Fill the remaining triangle on the left
                if effectiveColors.count > 0 {
                    var leftPath = Path()
                    leftPath.move(to: CGPoint(x: 0, y: 0))
                    leftPath.addLine(to: CGPoint(x: 0, y: canvasSize.height))
                    leftPath.addLine(to: CGPoint(x: canvasSize.height, y: canvasSize.height))
                    leftPath.closeSubpath()
                    context.fill(leftPath, with: .color(effectiveColors[0]))
                }
            }

        case .gradient:
            LinearGradient(
                colors: effectiveColors,
                startPoint: .top,
                endPoint: .bottom
            )

        case .horizontalGradient:
            LinearGradient(
                colors: effectiveColors,
                startPoint: .leading,
                endPoint: .trailing
            )

        case .radialGradient:
            RadialGradient(
                colors: effectiveColors,
                center: .center,
                startRadius: 0,
                endRadius: max(size.width, size.height) / 2
            )

        case .checkerboard:
            Canvas { context, canvasSize in
                let baseCols = max(effectiveColors.count * 2, 4)
                let cols = Int(CGFloat(baseCols) * CGFloat(patternScale))
                let rows = Int(Double(cols) * (canvasSize.height / canvasSize.width))
                let cellWidth = canvasSize.width / CGFloat(cols)
                let cellHeight = canvasSize.height / CGFloat(max(1, rows))

                for row in 0..<max(1, rows) {
                    for col in 0..<cols {
                        let colorIndex = (row + col) % effectiveColors.count
                        let rect = CGRect(
                            x: CGFloat(col) * cellWidth,
                            y: CGFloat(row) * cellHeight,
                            width: cellWidth + 1,
                            height: cellHeight + 1
                        )
                        context.fill(Path(rect), with: .color(effectiveColors[colorIndex]))
                    }
                }
            }

        case .quadrants:
            let c = paddedColors(count: 4)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle().fill(c[0])
                    Rectangle().fill(c[1])
                }
                HStack(spacing: 0) {
                    Rectangle().fill(c[2])
                    Rectangle().fill(c[3])
                }
            }

        case .halfVertical:
            let c = paddedColors(count: 2)
            HStack(spacing: 0) {
                Rectangle().fill(c[0])
                Rectangle().fill(c[1])
            }

        case .halfHorizontal:
            let c = paddedColors(count: 2)
            VStack(spacing: 0) {
                Rectangle().fill(c[0])
                Rectangle().fill(c[1])
            }

        case .diagonalSplit:
            let c = paddedColors(count: 2)
            Canvas { context, canvasSize in
                // Top-left triangle
                var path1 = Path()
                path1.move(to: CGPoint(x: 0, y: 0))
                path1.addLine(to: CGPoint(x: canvasSize.width, y: 0))
                path1.addLine(to: CGPoint(x: 0, y: canvasSize.height))
                path1.closeSubpath()
                context.fill(path1, with: .color(c[0]))

                // Bottom-right triangle
                var path2 = Path()
                path2.move(to: CGPoint(x: canvasSize.width, y: 0))
                path2.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
                path2.addLine(to: CGPoint(x: 0, y: canvasSize.height))
                path2.closeSubpath()
                context.fill(path2, with: .color(c[1]))
            }

        case .radialFromBasket:
            // Basket is at top center, approximately 4/47 from top
            let basketY = 4.0 / 47.0
            Canvas { context, canvasSize in
                let basketCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height * basketY)
                let maxRadius = sqrt(pow(canvasSize.width, 2) + pow(canvasSize.height, 2))
                let ringWidth = maxRadius / CGFloat(effectiveColors.count)

                // Draw from outside in so inner rings are on top
                for i in (0..<effectiveColors.count).reversed() {
                    let radius = ringWidth * CGFloat(i + 1)
                    let rect = CGRect(
                        x: basketCenter.x - radius,
                        y: basketCenter.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(effectiveColors[i]))
                }
            }

        case .zonesBased:
            // 6 standard basketball zones using actual court dimensions
            // c[0]=Restricted, c[1]=Paint, c[2]=Mid-range, c[3]=Corner 3, c[4]=Above break 3, c[5]=Deep
            let c = paddedColors(count: 6)
            let threePointArcFeet = courtType.threePointArc
            let corner3Feet = courtType.threePointCorner
            let basketDistanceFeet = courtType.basketDistance

            Canvas { context, canvasSize in
                let w = canvasSize.width
                let h = canvasSize.height

                // Court dimensions: 50' wide, 47' deep (half court)
                func x(_ feet: CGFloat) -> CGFloat { feet / 50.0 * w }
                func y(_ feet: CGFloat) -> CGFloat { feet / 47.0 * h }

                let basketFeetX: CGFloat = 25
                let basketCenter = CGPoint(x: x(basketFeetX), y: y(basketDistanceFeet))

                // Zone boundaries
                let restrictedRadiusFeet: CGFloat = 4.0  // 4ft restricted area
                let threePointPlusFeet = threePointArcFeet + 4.0  // Normal 3PT range
                let keyWidthFeet = courtType.keyWidth
                let freeThrowDistFeet = courtType.freeThrowLineDistance

                // Calculate where the extended 3PT arc meets the corner lines (for corner zone height)
                let dxFeet = corner3Feet - basketFeetX
                let arcPlusIntersectYFeet = basketDistanceFeet + sqrt(threePointPlusFeet * threePointPlusFeet - dxFeet * dxFeet)

                // Helper to create arc-based zone path
                func createArcZonePath(radiusFeet: CGFloat) -> Path {
                    var path = Path()
                    let radiusPixels = x(radiusFeet)
                    let distToCorner = basketFeetX - corner3Feet

                    if radiusFeet >= distToCorner {
                        let dxFeet = corner3Feet - basketFeetX
                        let intersectYFeet = basketDistanceFeet + sqrt(radiusFeet * radiusFeet - dxFeet * dxFeet)
                        let leftCornerX = x(corner3Feet)
                        let rightCornerX = w - leftCornerX
                        let intersectY = y(intersectYFeet)

                        path.move(to: CGPoint(x: leftCornerX, y: 0))
                        path.addLine(to: CGPoint(x: leftCornerX, y: intersectY))

                        let leftAngle = atan2(intersectY - basketCenter.y, leftCornerX - basketCenter.x)
                        let rightAngle = atan2(intersectY - basketCenter.y, rightCornerX - basketCenter.x)

                        path.addArc(center: basketCenter, radius: radiusPixels,
                                    startAngle: Angle(radians: leftAngle),
                                    endAngle: Angle(radians: rightAngle),
                                    clockwise: true)

                        path.addLine(to: CGPoint(x: rightCornerX, y: 0))
                        path.closeSubpath()
                    } else {
                        let leftX = basketCenter.x - radiusPixels
                        let rightX = basketCenter.x + radiusPixels
                        path.move(to: CGPoint(x: leftX, y: 0))
                        path.addLine(to: CGPoint(x: leftX, y: basketCenter.y))
                        path.addArc(center: basketCenter, radius: radiusPixels,
                                    startAngle: Angle(degrees: 180),
                                    endAngle: Angle(degrees: 0),
                                    clockwise: true)
                        path.addLine(to: CGPoint(x: rightX, y: 0))
                        path.closeSubpath()
                    }
                    return path
                }

                // 1. Deep zone (background) - beyond normal 3PT range
                context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(c[5]))

                // 2. Above the break 3s - the arc portion of 3PT zone (fills entire 3PT band first)
                context.fill(createArcZonePath(radiusFeet: threePointPlusFeet), with: .color(c[4]))

                // 3. Corner 3s - rectangular areas in corners (overwrite corners)
                let leftCornerX = x(corner3Feet)
                let rightCornerX = w - leftCornerX
                let arcPlusIntersectY = y(arcPlusIntersectYFeet)

                // Left corner 3 zone
                var leftCorner = Path()
                leftCorner.move(to: CGPoint(x: 0, y: 0))
                leftCorner.addLine(to: CGPoint(x: 0, y: arcPlusIntersectY))
                leftCorner.addLine(to: CGPoint(x: leftCornerX, y: arcPlusIntersectY))
                leftCorner.addLine(to: CGPoint(x: leftCornerX, y: 0))
                leftCorner.closeSubpath()
                context.fill(leftCorner, with: .color(c[3]))

                // Right corner 3 zone
                var rightCorner = Path()
                rightCorner.move(to: CGPoint(x: rightCornerX, y: 0))
                rightCorner.addLine(to: CGPoint(x: rightCornerX, y: arcPlusIntersectY))
                rightCorner.addLine(to: CGPoint(x: w, y: arcPlusIntersectY))
                rightCorner.addLine(to: CGPoint(x: w, y: 0))
                rightCorner.closeSubpath()
                context.fill(rightCorner, with: .color(c[3]))

                // 4. Mid-range - inside 3PT line, outside paint
                context.fill(createArcZonePath(radiusFeet: threePointArcFeet), with: .color(c[2]))

                // 5. Paint - rectangular key/lane
                let keyLeft = x(basketFeetX - keyWidthFeet / 2)
                let keyRight = x(basketFeetX + keyWidthFeet / 2)
                let keyTop = y(freeThrowDistFeet)

                var paintPath = Path()
                paintPath.move(to: CGPoint(x: keyLeft, y: 0))
                paintPath.addLine(to: CGPoint(x: keyLeft, y: keyTop))
                paintPath.addLine(to: CGPoint(x: keyRight, y: keyTop))
                paintPath.addLine(to: CGPoint(x: keyRight, y: 0))
                paintPath.closeSubpath()
                context.fill(paintPath, with: .color(c[1]))

                // 6. Restricted area - 4ft semicircle from basket
                let restrictedRadius = x(restrictedRadiusFeet)
                var restrictedPath = Path()
                restrictedPath.move(to: CGPoint(x: basketCenter.x - restrictedRadius, y: 0))
                restrictedPath.addLine(to: CGPoint(x: basketCenter.x - restrictedRadius, y: basketCenter.y))
                restrictedPath.addArc(center: basketCenter, radius: restrictedRadius,
                                      startAngle: Angle(degrees: 180),
                                      endAngle: Angle(degrees: 0),
                                      clockwise: true)
                restrictedPath.addLine(to: CGPoint(x: basketCenter.x + restrictedRadius, y: 0))
                restrictedPath.closeSubpath()
                context.fill(restrictedPath, with: .color(c[0]))
            }
        }
    }

    /// Ensure we have at least `count` colors by repeating existing colors
    private func paddedColors(count: Int) -> [Color] {
        guard !effectiveColors.isEmpty else {
            return Array(repeating: Color.gray.opacity(Double(alpha)), count: count)
        }
        var result = effectiveColors
        while result.count < count {
            result.append(contentsOf: effectiveColors)
        }
        return Array(result.prefix(count))
    }
}

#Preview {
    CourtView(shots: []) { location, made in
        print("Tap at \(location), made: \(made)")
    }
    .frame(width: 400, height: 350)
    .padding()
}

#Preview("Custom Theme - Stripes") {
    CourtView(
        shots: [],
        theme: CourtTheme(
            backgroundColors: [.red, .white, .blue],
            backgroundAlpha: 0.8,
            lineColor: .white,
            pattern: .verticalStripes
        )
    ) { location, made in
        print("Tap at \(location), made: \(made)")
    }
    .frame(width: 400, height: 350)
    .padding()
}

#Preview("Custom Theme - Zones") {
    CourtView(
        shots: [],
        theme: CourtTheme(
            backgroundColors: [.green, .yellow, .orange, .red],
            backgroundAlpha: 0.7,
            lineColor: .white,
            pattern: .zonesBased
        )
    ) { location, made in
        print("Tap at \(location), made: \(made)")
    }
    .frame(width: 400, height: 350)
    .padding()
}
