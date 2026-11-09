import SwiftUI

/// Identicon の描画（パターンは ViewModel 層の IdenticonPattern）。相対座標で描くのでサイズに依存しない。
struct IdenticonView: View {
    let pattern: IdenticonPattern
    let size: CGFloat

    init(publicUserId: String, avatarVersion: Int, size: CGFloat) {
        pattern = IdenticonPattern(publicUserId: publicUserId, avatarVersion: avatarVersion)
        self.size = size
    }

    init(profile: PublicProfile, size: CGFloat) {
        self.init(publicUserId: profile.publicUserId, avatarVersion: profile.avatarVersion, size: size)
    }

    var body: some View {
        let background = Color(hex: pattern.palette.background)
        let foreground = Color(hex: pattern.palette.foreground)
        let cells = pattern.cells
        Canvas { context, canvasSize in
            let side = min(canvasSize.width, canvasSize.height)
            let padding = side * 0.1
            let cell = (side - padding * 2) / CGFloat(IdenticonPattern.size)
            context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(background))
            for (row, rowCells) in cells.enumerated() {
                for (column, filled) in rowCells.enumerated() where filled {
                    let rect = CGRect(x: padding + CGFloat(column) * cell, y: padding + CGFloat(row) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(foreground))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        .accessibilityHidden(true)
    }
}

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview {
    HStack {
        IdenticonView(profile: PublicProfile(publicUserId: "b24683ec-304d-40f6-a1d1-8c8e52a3d09d", displayName: "A", avatarVersion: 1), size: 80)
        IdenticonView(profile: PublicProfile(publicUserId: "id_001", displayName: "A", avatarVersion: 1), size: 80)
    }
}
