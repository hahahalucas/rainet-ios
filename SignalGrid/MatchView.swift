import SwiftUI

struct MatchView: View {
    @ObservedObject var store: MatchStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Cell?
    @State private var command: Command?
    @State private var confirmedTurn: TurnID?
    @State private var showRules = false
    @State private var confirmResign = false

    var body: some View {
        Group {
            if let match = store.current {
                let game = match.game
                let id = TurnID(match: match.id, ply: game.ply)
                let waitingForHandoff = match.mode == .local && game.outcome == nil && confirmedTurn != id
                let canPlay = game.outcome == nil && (match.mode == .local || game.turn == .jade)
                Screen {
                    VStack(spacing: 14) {
                        ScoresView(game: game)
                        if waitingForHandoff {
                            handoff(for: game.turn, id: id)
                        } else {
                            board(for: match, canPlay: canPlay, id: id)
                        }
                        if let message = store.storageMessage {
                            Text(message).font(.footnote).foregroundStyle(Palette.ember)
                        }
                    }
                }
                .task(id: SearchID(turn: id, active: scenePhase == .active)) {
                    guard scenePhase == .active else { return }
                    await store.playOpponent(in: id.match, ply: id.ply)
                }
                .onChange(of: id) { resetSelection() }
                .onChange(of: scenePhase) {
                    if scenePhase != .active && match.mode == .local {
                        confirmedTurn = nil
                        resetSelection()
                    }
                }
                .toolbar {
                    Menu("对局选项", systemImage: "ellipsis.circle") {
                        Button("查看规则", systemImage: "questionmark.circle") { showRules = true }
                        if canPlay && !waitingForHandoff {
                            Button("认输", systemImage: "flag", role: .destructive) { confirmResign = true }
                        }
                    }
                }
                .confirmationDialog("\(game.turn.name)认输？", isPresented: $confirmResign, titleVisibility: .visible) {
                    Button("认输", role: .destructive) {
                        if canPlay { store.play(.resign, in: id.match, ply: id.ply) }
                    }
                }
            } else {
                ContentUnavailableView("暂无对局", systemImage: "square.grid.3x3")
            }
        }
        .navigationTitle(store.current?.detail ?? "对局")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRules) { RulesView() }
    }

    private func board(for match: MatchRecord, canPlay: Bool, id: TurnID) -> some View {
        let game = match.game
        let perspective: BoardPerspective = game.outcome != nil
            ? .everyone : .camp(match.mode == .solo ? .jade : game.turn)
        return VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                if let result = game.outcome {
                    Label(result.title, systemImage: "flag.checkered").font(.headline)
                } else if canPlay {
                    Circle().fill(game.turn.color).frame(width: 8, height: 8)
                    Text("\(game.turn.name)行动").font(.headline)
                } else {
                    ProgressView().controlSize(.small)
                    Text("AI 正在思考").font(.headline)
                }
                Spacer()
                Text("第 \(game.outcome == nil ? game.ply + 1 : game.ply) 手")
                    .font(.caption.monospacedDigit()).foregroundStyle(Palette.secondary)
            }

            BoardView(game: game, perspective: perspective, selected: selection,
                      highlights: canPlay ? targets(in: game) : [],
                      onSelect: canPlay ? { cell in select(cell, in: game, id: id) } : nil)

            Text(game.event)
                .font(.subheadline).foregroundStyle(Palette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .modifier(Panel())
                .accessibilityLabel("上一手，\(game.event)")

            if game.outcome != nil {
                Button("返回主页") { dismiss() }.buttonStyle(PrimaryButton())
            } else if canPlay {
                controls(for: game, id: id)
            }
        }
    }

    private func handoff(for camp: Camp, id: TurnID) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 28)).foregroundStyle(camp.color).accessibilityHidden(true)
            Text("请交给\(camp.name)").font(.title2.bold())
            Text("由\(camp.name)确认后显示棋盘和己方身份。")
                .font(.subheadline).foregroundStyle(Palette.secondary)
            Button("\(camp.name)已就绪") { confirmedTurn = id }
                .buttonStyle(PrimaryButton())
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 285)
        .padding(18)
        .modifier(Panel())
    }

    private func controls(for game: Game, id: TurnID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selection, game.canTransmit(at: selection) {
                Button("传输信号 · +2", systemImage: "antenna.radiowaves.left.and.right") {
                    store.play(.transmit(selection), in: id.match, ply: id.ply)
                }
                .buttonStyle(PrimaryButton())
            }
            Text(command?.instruction ?? "先选己方棋子，再选高亮格移动。")
                .font(.footnote).foregroundStyle(Palette.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) { commandButtons(for: game) }
                VStack(spacing: 7) { commandButtons(for: game) }
            }
        }
    }

    private func commandButtons(for game: Game) -> some View {
        ForEach(Command.allCases) { item in
            let used = game.tally(for: game.turn).used.contains(item)
            Button {
                command = command == item ? nil : item
                selection = nil
            } label: {
                Label(item.name, systemImage: used ? "checkmark" : item.symbol)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(command == item ? Palette.jade.opacity(0.22) : Palette.panel,
                                in: RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(command == item ? Palette.jade : Palette.foreground)
            .disabled(!game.hasTarget(for: item))
            .opacity(game.hasTarget(for: item) ? 1 : 0.40)
            .accessibilityValue(used ? "已使用" : "")
        }
    }

    private func targets(in game: Game) -> Set<Cell> {
        switch command {
        case .scan: return Set(game.scanTargets())
        case .barrier: return Set(game.barrierTargets())
        case .jump:
            if let selection { return Set(game.targets(from: selection, jumping: true)) }
            return Set(game.pieces.filter { !game.targets(from: $0.cell, jumping: true).isEmpty }.map(\.cell))
        case nil:
            return selection.map { Set(game.targets(from: $0)) } ?? []
        }
    }

    private func select(_ cell: Cell, in game: Game, id: TurnID) {
        switch command {
        case .scan:
            if game.scanTargets().contains(cell) { store.play(.scan(cell), in: id.match, ply: id.ply) }
        case .barrier:
            if game.barrierTargets().contains(cell) { store.play(.barrier(cell), in: id.match, ply: id.ply) }
        case .jump, nil:
            let jumping = command == .jump
            if let selection, game.targets(from: selection, jumping: jumping).contains(cell) {
                store.play(.move(from: selection, to: cell, jump: jumping), in: id.match, ply: id.ply)
            } else if game.piece(at: cell)?.camp == game.turn {
                selection = selection == cell ? nil : cell
            } else {
                selection = nil
            }
        }
    }

    private func resetSelection() {
        selection = nil
        command = nil
    }
}

private struct TurnID: Hashable {
    let match: UUID
    let ply: Int
}

private struct SearchID: Hashable {
    let turn: TurnID
    let active: Bool
}
