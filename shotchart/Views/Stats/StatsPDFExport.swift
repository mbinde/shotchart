import SwiftUI
import UIKit

// MARK: - PDF Drawing Helpers

private func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor = .black) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    text.draw(at: point, withAttributes: attributes)
}

private func drawCenteredText(_ text: String, in rect: CGRect, font: UIFont, color: UIColor = .black) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let size = text.size(withAttributes: attributes)
    let x = rect.origin.x + (rect.width - size.width) / 2
    let y = rect.origin.y + (rect.height - size.height) / 2
    text.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
}

private struct PDFStats {
    let twoA: Int
    let twoM: Int
    let threeA: Int
    let threeM: Int
    let ftA: Int
    let ftM: Int
    let fgA: Int
    let fgM: Int
    let fgPct: Double
    let efgPct: Double

    init(shots: [Shot]) {
        let twos = shots.filter { $0.type == ShotType.twoPointer.rawValue }
        let threes = shots.filter { $0.type == ShotType.threePointer.rawValue }
        let fts = shots.filter { $0.type == ShotType.freeThrow.rawValue }

        twoA = twos.count
        twoM = twos.filter { $0.made }.count
        threeA = threes.count
        threeM = threes.filter { $0.made }.count
        ftA = fts.count
        ftM = fts.filter { $0.made }.count
        fgA = twoA + threeA
        fgM = twoM + threeM
        fgPct = fgA > 0 ? Double(fgM) / Double(fgA) * 100 : 0
        efgPct = fgA > 0 ? (Double(fgM) + 0.5 * Double(threeM)) / Double(fgA) * 100 : 0
    }
}

// MARK: - PDF Generation

@MainActor
func generateStatsPDF(
    gameDate: Date,
    teamName: String?,
    shots: [Shot],
    playerData: [(number: Int16, name: String?)]
) -> Data? {
    let pageWidth: CGFloat = 612
    let pageHeight: CGFloat = 792
    let margin: CGFloat = 40
    let contentWidth = pageWidth - (margin * 2)

    let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

    let data = pdfRenderer.pdfData { context in
        context.beginPage()

        var yPos: CGFloat = margin

        // Fonts
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let subtitleFont = UIFont.systemFont(ofSize: 16)
        let captionFont = UIFont.systemFont(ofSize: 12)
        let sectionHeaderFont = UIFont.boldSystemFont(ofSize: 14)
        let tableHeaderFont = UIFont.boldSystemFont(ofSize: 10)
        let tableFont = UIFont.systemFont(ofSize: 10)
        let tableBoldFont = UIFont.boldSystemFont(ofSize: 10)

        // MARK: Header
        drawText("Game Statistics", at: CGPoint(x: margin, y: yPos), font: titleFont)
        yPos += 30

        if let teamName = teamName, !teamName.isEmpty {
            drawText(teamName, at: CGPoint(x: margin, y: yPos), font: subtitleFont, color: .darkGray)
            yPos += 22
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        drawText(dateFormatter.string(from: gameDate), at: CGPoint(x: margin, y: yPos), font: captionFont, color: .gray)
        yPos += 30

        // MARK: Game Summary
        let firstHalfShots = shots.filter { $0.quarter == 1 || $0.quarter == 2 }
        let secondHalfShots = shots.filter { $0.quarter == 3 || $0.quarter == 4 }

        let firstHalfStats = PDFStats(shots: firstHalfShots)
        let secondHalfStats = PDFStats(shots: secondHalfShots)
        let fullGameStats = PDFStats(shots: shots)

        let gameSectionHeight: CGFloat = 118
        let sectionRect = CGRect(x: margin, y: yPos, width: contentWidth, height: gameSectionHeight)
        UIColor(white: 0.95, alpha: 1.0).setFill()
        UIBezierPath(roundedRect: sectionRect, cornerRadius: 8).fill()

        yPos += 12
        drawText("Game Summary", at: CGPoint(x: margin + 12, y: yPos), font: sectionHeaderFont)
        yPos += 20

        // Game stats headers
        let gameColWidths: [CGFloat] = [70, 32, 32, 32, 32, 32, 32, 32, 32, 42, 42]
        let gameHeaders = ["Period", "2Pa", "2Pm", "3Pa", "3Pm", "FTa", "FTm", "FGa", "FGm", "FG%", "eFG%"]

        var xPos = margin + 12
        for (i, header) in gameHeaders.enumerated() {
            if i == 0 {
                drawText(header, at: CGPoint(x: xPos, y: yPos), font: tableHeaderFont, color: .darkGray)
            } else {
                drawCenteredText(header, in: CGRect(x: xPos, y: yPos, width: gameColWidths[i], height: 14), font: tableHeaderFont, color: .darkGray)
            }
            xPos += gameColWidths[i]
        }
        yPos += 18

        // Divider
        UIColor.lightGray.setStroke()
        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: margin + 12, y: yPos))
        dividerPath.addLine(to: CGPoint(x: margin + contentWidth - 12, y: yPos))
        dividerPath.lineWidth = 0.5
        dividerPath.stroke()
        yPos += 6

        // Period rows
        yPos = drawPeriodRow(label: "1st Half", stats: firstHalfStats, yPos: yPos, margin: margin, colWidths: gameColWidths, font: tableFont)
        yPos = drawPeriodRow(label: "2nd Half", stats: secondHalfStats, yPos: yPos, margin: margin, colWidths: gameColWidths, font: tableFont)
        yPos += 2
        yPos = drawPeriodRow(label: "Full Game", stats: fullGameStats, yPos: yPos, margin: margin, colWidths: gameColWidths, font: tableBoldFont)

        yPos += 30

        // MARK: Player Statistics
        var playerNumbers = Set(shots.map { $0.playerNumber })
        playerNumbers.remove(0)
        let sortedPlayerNumbers = playerNumbers.sorted()
        let hasUnassigned = shots.contains { $0.playerNumber == 0 }

        if !sortedPlayerNumbers.isEmpty || hasUnassigned {
            let playerRowCount = sortedPlayerNumbers.count + (hasUnassigned ? 1 : 0)
            let playerSectionHeight: CGFloat = CGFloat(92 + playerRowCount * 16)

            let playerSectionRect = CGRect(x: margin, y: yPos, width: contentWidth, height: playerSectionHeight)
            UIColor(white: 0.95, alpha: 1.0).setFill()
            UIBezierPath(roundedRect: playerSectionRect, cornerRadius: 8).fill()

            yPos += 12
            drawText("Player Statistics", at: CGPoint(x: margin + 12, y: yPos), font: sectionHeaderFont)
            yPos += 20

            // Player stats headers
            let playerColWidths: [CGFloat] = [35, 80, 32, 32, 32, 32, 32, 32, 32, 32, 42, 42]
            let playerHeaders = ["#", "Name", "2Pa", "2Pm", "3Pa", "3Pm", "FTa", "FTm", "FGa", "FGm", "FG%", "eFG%"]

            xPos = margin + 12
            for (i, header) in playerHeaders.enumerated() {
                if i <= 1 {
                    drawText(header, at: CGPoint(x: xPos, y: yPos), font: tableHeaderFont, color: .darkGray)
                } else {
                    drawCenteredText(header, in: CGRect(x: xPos, y: yPos, width: playerColWidths[i], height: 14), font: tableHeaderFont, color: .darkGray)
                }
                xPos += playerColWidths[i]
            }
            yPos += 18

            // Divider
            let playerDividerPath = UIBezierPath()
            playerDividerPath.move(to: CGPoint(x: margin + 12, y: yPos))
            playerDividerPath.addLine(to: CGPoint(x: margin + contentWidth - 12, y: yPos))
            playerDividerPath.lineWidth = 0.5
            UIColor.lightGray.setStroke()
            playerDividerPath.stroke()
            yPos += 6

            // Player rows
            for number in sortedPlayerNumbers {
                let playerShots = shots.filter { $0.playerNumber == number }
                let stats = PDFStats(shots: playerShots)
                let name = playerData.first { $0.number == number }?.name
                yPos = drawPlayerRow(number: number, name: name, stats: stats, yPos: yPos, margin: margin, colWidths: playerColWidths, font: tableFont)
            }

            if hasUnassigned {
                let unassignedShots = shots.filter { $0.playerNumber == 0 }
                let stats = PDFStats(shots: unassignedShots)
                yPos = drawPlayerRow(number: 0, name: nil, stats: stats, yPos: yPos, margin: margin, colWidths: playerColWidths, font: tableFont)
            }

            yPos += 2

            // Divider before total
            let totalDividerPath = UIBezierPath()
            totalDividerPath.move(to: CGPoint(x: margin + 12, y: yPos))
            totalDividerPath.addLine(to: CGPoint(x: margin + contentWidth - 12, y: yPos))
            totalDividerPath.lineWidth = 0.5
            UIColor.lightGray.setStroke()
            totalDividerPath.stroke()
            yPos += 6

            // Total row
            _ = drawPlayerRow(number: -1, name: "Total", stats: fullGameStats, yPos: yPos, margin: margin, colWidths: playerColWidths, font: tableBoldFont)
        }

        // MARK: Footer
        let footerFont = UIFont.systemFont(ofSize: 10)
        let footerText = "Generated by HoopChart"
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: UIColor.gray
        ]
        let footerSize = footerText.size(withAttributes: footerAttributes)
        footerText.draw(at: CGPoint(x: pageWidth - margin - footerSize.width, y: pageHeight - margin), withAttributes: footerAttributes)
    }

    return data
}

// MARK: - Row Drawing Helpers

private func drawPeriodRow(label: String, stats: PDFStats, yPos: CGFloat, margin: CGFloat, colWidths: [CGFloat], font: UIFont) -> CGFloat {
    var x = margin + 12
    drawText(label, at: CGPoint(x: x, y: yPos), font: font)
    x += colWidths[0]

    let values = ["\(stats.twoA)", "\(stats.twoM)", "\(stats.threeA)", "\(stats.threeM)",
                  "\(stats.ftA)", "\(stats.ftM)", "\(stats.fgA)", "\(stats.fgM)",
                  String(format: "%.0f%%", stats.fgPct), String(format: "%.0f%%", stats.efgPct)]

    for (i, value) in values.enumerated() {
        drawCenteredText(value, in: CGRect(x: x, y: yPos, width: colWidths[i + 1], height: 12), font: font)
        x += colWidths[i + 1]
    }
    return yPos + 16
}

private func drawPlayerRow(number: Int16, name: String?, stats: PDFStats, yPos: CGFloat, margin: CGFloat, colWidths: [CGFloat], font: UIFont) -> CGFloat {
    var x = margin + 12

    // Number column
    if number == -1 {
        // Total row - empty number
    } else if number > 0 {
        drawText("#\(number)", at: CGPoint(x: x, y: yPos), font: font)
    } else {
        drawText("--", at: CGPoint(x: x, y: yPos), font: font, color: .gray)
    }
    x += colWidths[0]

    // Name column
    let displayName = number == -1 ? "Total" : (name ?? (number == 0 ? "Unassigned" : ""))
    drawText(displayName, at: CGPoint(x: x, y: yPos), font: font)
    x += colWidths[1]

    // Stats columns
    let values = ["\(stats.twoA)", "\(stats.twoM)", "\(stats.threeA)", "\(stats.threeM)",
                  "\(stats.ftA)", "\(stats.ftM)", "\(stats.fgA)", "\(stats.fgM)",
                  String(format: "%.0f%%", stats.fgPct), String(format: "%.0f%%", stats.efgPct)]

    for (i, value) in values.enumerated() {
        drawCenteredText(value, in: CGRect(x: x, y: yPos, width: colWidths[i + 2], height: 12), font: font)
        x += colWidths[i + 2]
    }
    return yPos + 16
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
