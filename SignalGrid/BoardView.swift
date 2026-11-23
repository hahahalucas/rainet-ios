import SwiftUI

enum BoardPerspective {
    case camp(Camp)
    case everyone

    func canSee(_ piece: Piece) -> Bool {
        if piece.revealed { return true }
        switch self {
        case .camp(let camp): return piece.camp == camp
        case .everyone: return true
        }
    }
}

struct BoardView: View {
    let game: Game
    let perspective: BoardPerspective
    var selected: Cell?
    var highlights: Set<Cell> = []
    var onSelect: ((Cell) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let gap: CGFloat = 3
            let inset: CGFloat = 18
            let side = max(1, (geometry.size.width - inset - CGFloat(Game.size - 1) * gap) / CGFloat(Game.size))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: gap) {
                    Color.clear.frame(width: inset - gap, height: inset)
                    ForEach(Cell.columns, id: \.self) { column in
                        Text(column).frame(width: side, height: inset)
                    }
                }
                .accessibilityHidden(true)
                ForEach(0..<Game.size, id: \.self) { row in
                    HStack(spacing: gap) {
                        Text("\(row + 1)").frame(width: inset - gap).accessibilityHidden(true)
                        ForEach(0..<Game.size, id: \.self) { column in
                            tile(at: Cell(row: row, column: column), size: side)
                        }
                    }
                    .padding(.bottom, row == Game.size - 1 ? 0 : gap)
                }
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.secondary)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("7 × 7 棋盘")
    }

    @ViewBuilder
    private func tile(at cell: Cell, size: CGFloat) -> some View {
        let tile = BoardTile(
            coordinate: cell, piece: game.piece(at: cell),
            relay: Camp.allCases.first { $0.relay == cell }, blocked: game.blocked == cell,
            perspective: perspective, selected: cell == selected, highlighted: highlights.contains(cell), size: size
        )
        if let onSelect {
            Button { onSelect(cell) } label: { tile }
                .buttonStyle(.plain)
                .accessibilityLabel(tile.spokenLabel)
                .accessibilityAddTraits(cell == selected ? .isSelected : [])
        } else {
            tile.accessibilityElement(children: .ignore).accessibilityLabel(tile.spokenLabel)
        }
    }
}

private struct BoardTile: View {
    let coordinate: Cell
    let piece: Piece?
    let relay: Camp?
    let blocked: Bool
    let perspective: BoardPerspective
    let selected: Bool
    let highlighted: Bool
    let size: CGFloat

    var spokenLabel: String {
        var words = [coordinate.label]
        if let relay { words.append("\(relay.name)中继点") }
        if let piece {
            words.append(piece.camp.name + (perspective.canSee(piece) ? piece.role.name : "隐藏棋子"))
        } else if blocked {
            words.append("已阻断")
        } else if relay == nil {
            words.append("空格")
        }
        if highlighted { words.append("可选目标") }
        return words.joined(separator: "，")
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(3, size * 0.15))
        ZStack {
            shape.fill(background)
            shape.strokeBorder(outline, lineWidth: selected || highlighted ? 1.6 : 1)
            if let piece {
                pieceMark(piece)
            } else if blocked {
                Image(systemName: "lock.fill").foregroundStyle(Palette.ember)
            } else if let relay {
                Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(relay.color)
            } else if highlighted {
                Circle().fill(Palette.jade).frame(width: size * 0.14)
            }
        }
        .font(.system(size: size * 0.36, weight: .semibold))
        .frame(width: size, height: size)
        .contentShape(Rectangle())
    }

    private var background: Color {
        if selected { return Palette.jade.opacity(0.24) }
        if let relay { return relay.color.opacity(0.13) }
        if highlighted { return Palette.jade.opacity(0.12) }
        return (coordinate.row + coordinate.column).isMultiple(of: 2)
            ? Palette.panel : Palette.panel.opacity(0.60)
    }

    private var outline: Color {
        if selected || highlighted { return Palette.jade.opacity(0.85) }
        if let relay { return relay.color.opacity(0.48) }
        return Palette.border.opacity(0.6)
    }

    private func pieceMark(_ piece: Piece) -> some View {
        let known = perspective.canSee(piece)
        let symbol = known ? (piece.role == .courier ? "paperplane.fill" : "diamond.fill") : "questionmark"
        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(piece.camp.color.opacity(known ? 0.18 : 0.09))
                .overlay { Circle().strokeBorder(piece.camp.color.opacity(0.82), lineWidth: 1) }
                .overlay { Image(systemName: symbol).foregroundStyle(piece.camp.color) }
            if piece.revealed {
                Circle().fill(Palette.foreground).frame(width: size * 0.12)
            }
        }
        .frame(width: size * 0.72, height: size * 0.72)
    }
}

struct ScoresView: View {
    let game: Game

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { tally(.jade); tally(.ember) }
            VStack(spacing: 8) { tally(.jade); tally(.ember) }
        }
    }

    private func tally(_ camp: Camp) -> some View {
        let points = game.tally(for: camp).points
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle().fill(camp.color).frame(width: 8, height: 8)
                Text(camp.name).font(.subheadline.bold())
                Spacer(minLength: 8)
                Text("\(points)/\(Game.target)").font(.subheadline.monospacedDigit())
            }
            HStack(spacing: 4) {
                ForEach(0..<Game.target, id: \.self) { marker in
                    Capsule().fill(marker < points ? camp.color : Palette.border).frame(height: 4)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(Panel())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(camp.name)，\(points) 分，目标 \(Game.target) 分")
    }
}
