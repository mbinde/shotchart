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
    let onTap: (CGPoint, Bool) -> Void
    @AppStorage("useWoodFloor") private var useWoodFloor = true
    @AppStorage("courtType") private var courtTypeRaw = CourtType.highSchool.rawValue

    private var courtType: CourtType {
        CourtType(rawValue: courtTypeRaw) ?? .highSchool
    }

    var body: some View {
        GeometryReader { geometry in
            let courtSize = calculateCourtSize(in: geometry.size)

            ZStack {
                // Court background
                if useWoodFloor {
                    Image("wood-floor")
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(red: 0.93, green: 0.87, blue: 0.75))
                }

                // Court lines - explicit frame to ensure correct size
                Canvas { context, size in
                    drawCourt(context: context, size: size, lineColor: useWoodFloor ? .white : .black, courtType: courtType)
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
            // Arc doesn't reach corners - draw full arc to baseline (High School)
            // Calculate where arc intersects the baseline (y = 0)
            let baselineIntersectX = sqrt(arcRadiusFeet * arcRadiusFeet - basketFeetY * basketFeetY)
            let leftX = basketFeetX - baselineIntersectX
            let rightX = basketFeetX + baselineIntersectX

            // Arc from left baseline intersection to right baseline intersection
            let leftAngle = atan2(-basketCenter.y, x(leftX) - basketCenter.x)
            let rightAngle = atan2(-basketCenter.y, x(rightX) - basketCenter.x)

            path.addArc(center: basketCenter,
                        radius: arcRadiusPixels,
                        startAngle: Angle(radians: leftAngle),
                        endAngle: Angle(radians: rightAngle),
                        clockwise: true)
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

#Preview {
    CourtView(shots: []) { location, made in
        print("Tap at \(location), made: \(made)")
    }
    .frame(width: 400, height: 350)
    .padding()
}
