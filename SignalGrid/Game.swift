import Foundation

enum Camp: String, CaseIterable, Codable, Sendable {
    case jade, ember

    var opponent: Camp { self == .jade ? .ember : .jade }
    var name: String { self == .jade ? "青方" : "橙方" }
    var relay: Cell { Cell(row: self == .jade ? 0 : Game.size - 1, column: 3) }
}

enum Role: String, Codable, Sendable {
    case courier, decoy

    var name: String { self == .courier ? "信使" : "诱饵" }
}

enum Command: String, CaseIterable, Codable, Sendable, Identifiable {
    case scan, jump, barrier

    var id: Self { self }

    var name: String {
        switch self {
        case .scan: "侦察"
        case .jump: "跃迁"
        case .barrier: "阻断"
        }
    }

    var instruction: String {
        switch self {
        case .scan: "点选距离任一己方棋子两格以内的隐藏敌棋。"
        case .jump: "点选己方棋子，再选同一直线上的第二个空格。"
        case .barrier: "点选棋盘中间三行的空格，阻挡对手一手。"
        }
    }
}

struct Cell: Hashable, Codable, Sendable {
    static let columns = ["A", "B", "C", "D", "E", "F", "G"]
    let row: Int
    let column: Int

    var onBoard: Bool { (0..<Game.size).contains(row) && (0..<Game.size).contains(column) }
    var label: String { Self.columns[column] + "\(row + 1)" }

    func distance(to other: Cell) -> Int {
        abs(row - other.row) + abs(column - other.column)
    }

    func offset(row deltaRow: Int, column deltaColumn: Int) -> Cell {
        Cell(row: row + deltaRow, column: column + deltaColumn)
    }
}

struct Piece: Equatable, Codable, Sendable {
    let camp: Camp
    var role: Role
    var cell: Cell
    var revealed = false
}

struct Tally: Equatable, Codable, Sendable {
    var points = 0
    var couriersRemoved = 0
    var used: Set<Command> = []
}

enum Turn: Equatable, Codable, Sendable {
    case move(from: Cell, to: Cell, jump: Bool)
    case transmit(Cell)
    case scan(Cell)
    case barrier(Cell)
    case resign
}

enum Outcome: Equatable, Codable, Sendable {
    case victory(Camp)
    case draw

    var title: String {
        switch self {
        case .victory(let camp): "\(camp.name)获胜"
        case .draw: "平局"
        }
    }
}

struct Game: Equatable, Codable, Sendable {
    static let size = 7
    static let target = 5
    static let turnLimit = 80
    static let couriersPerCamp = 3
    private static let directions = [(-1, 0), (0, -1), (0, 1), (1, 0)]

    private(set) var turn: Camp = .jade
    private(set) var ply = 0
    private(set) var pieces: [Piece]
    private(set) var jade = Tally()
    private(set) var ember = Tally()
    private(set) var blocked: Cell?
    private(set) var outcome: Outcome?
    private(set) var event = "青方先行"

    init<R: RandomNumberGenerator>(using random: inout R) {
        let north = [
            Cell(row: 0, column: 2), Cell(row: 0, column: 4),
            Cell(row: 1, column: 0), Cell(row: 1, column: 2),
            Cell(row: 1, column: 4), Cell(row: 1, column: 6)
        ]
        let roles = Array(repeating: Role.courier, count: Self.couriersPerCamp)
            + Array(repeating: Role.decoy, count: north.count - Self.couriersPerCamp)
        let south = north.map { Cell(row: Self.size - 1 - $0.row, column: $0.column) }
        pieces = zip(south, roles.shuffled(using: &random)).map {
            Piece(camp: .jade, role: $0.1, cell: $0.0)
        } + zip(north, roles.shuffled(using: &random)).map {
            Piece(camp: .ember, role: $0.1, cell: $0.0)
        }
    }

    func tally(for camp: Camp) -> Tally { camp == .jade ? jade : ember }

    func piece(at cell: Cell) -> Piece? {
        pieces.first { $0.cell == cell }
    }

    func targets(from cell: Cell, jumping: Bool = false) -> [Cell] {
        guard outcome == nil, piece(at: cell)?.camp == turn else { return [] }
        if jumping && tally(for: turn).used.contains(.jump) { return [] }

        return Self.directions.compactMap { dy, dx in
            let adjacent = cell.offset(row: dy, column: dx)
            guard adjacent.onBoard, adjacent != blocked else { return nil }
            if jumping {
                let landing = adjacent.offset(row: dy, column: dx)
                guard piece(at: adjacent) == nil, landing.onBoard, landing != blocked,
                      piece(at: landing) == nil else { return nil }
                return landing
            }
            return piece(at: adjacent)?.camp == turn ? nil : adjacent
        }
    }

    func canTransmit(at cell: Cell) -> Bool {
        guard outcome == nil, cell == turn.relay, let piece = piece(at: cell) else { return false }
        return piece.camp == turn && piece.role == .courier
    }

    func scanTargets() -> [Cell] {
        guard outcome == nil, !tally(for: turn).used.contains(.scan) else { return [] }
        let allies = pieces.filter { $0.camp == turn }
        return pieces.filter { target in
            target.camp != turn && !target.revealed &&
            allies.contains { $0.cell.distance(to: target.cell) <= 2 }
        }.map(\.cell)
    }

    func barrierTargets() -> [Cell] {
        guard outcome == nil, !tally(for: turn).used.contains(.barrier) else { return [] }
        return (2...4).flatMap { row in
            (0..<Self.size).map { Cell(row: row, column: $0) }
        }.filter { $0 != blocked && piece(at: $0) == nil }
    }

    func hasTarget(for command: Command) -> Bool {
        switch command {
        case .scan: !scanTargets().isEmpty
        case .jump: pieces.contains { $0.camp == turn && !targets(from: $0.cell, jumping: true).isEmpty }
        case .barrier: !barrierTargets().isEmpty
        }
    }

    func legalTurns() -> [Turn] {
        guard outcome == nil else { return [] }
        var choices: [Turn] = []
        for piece in pieces where piece.camp == turn {
            let from = piece.cell
            if canTransmit(at: from) { choices.append(.transmit(from)) }
            choices += targets(from: from).map { .move(from: from, to: $0, jump: false) }
            choices += targets(from: from, jumping: true).map { .move(from: from, to: $0, jump: true) }
        }
        choices += scanTargets().map(Turn.scan)
        choices += barrierTargets().map(Turn.barrier)
        return choices
    }

    @discardableResult
    mutating func play(_ action: Turn) -> Bool {
        guard outcome == nil else { return false }
        let mover = turn
        var nextBlocked: Cell?

        switch action {
        case let .move(from, to, jump):
            guard targets(from: from, jumping: jump).contains(to) else { return false }
            let prefix = "\(mover.name) \(from.label) → \(to.label)"
            if let captured = removePiece(at: to) {
                let recipient = captured.role == .courier ? mover : mover.opponent
                changeTally(for: recipient) { $0.points += 1 }
                event = "\(prefix) · 捕获\(captured.role.name)，\(recipient.name) +1"
            } else {
                event = jump ? "\(prefix) · 跃迁" : prefix
            }
            if let moved = pieces.firstIndex(where: { $0.cell == from }) {
                pieces[moved].cell = to
            }
            if jump { changeTally(for: mover) { $0.used.insert(.jump) } }

        case .transmit(let cell):
            guard canTransmit(at: cell) else { return false }
            removePiece(at: cell)
            changeTally(for: mover) { $0.points += 2 }
            event = "\(mover.name)从 \(cell.label) 传输信号，+2"

        case .scan(let cell):
            guard scanTargets().contains(cell),
                  let index = pieces.firstIndex(where: { $0.cell == cell }) else { return false }
            pieces[index].revealed = true
            changeTally(for: mover) { $0.used.insert(.scan) }
            event = "\(mover.name)侦察 \(cell.label) · \(pieces[index].role.name)"

        case .barrier(let cell):
            guard barrierTargets().contains(cell) else { return false }
            nextBlocked = cell
            changeTally(for: mover) { $0.used.insert(.barrier) }
            event = "\(mover.name)阻断 \(cell.label)"

        case .resign:
            ply += 1
            outcome = .victory(mover.opponent)
            event = "\(mover.name)认输"
            return true
        }

        blocked = nextBlocked
        ply += 1
        turn = mover.opponent
        if let leader = Camp.allCases.first(where: { tally(for: $0).points >= Self.target }) {
            outcome = .victory(leader)
        } else if !pieces.contains(where: { $0.camp == turn }) {
            outcome = .victory(mover)
        } else if ply >= Self.turnLimit {
            if jade.points == ember.points {
                outcome = .draw
            } else {
                outcome = .victory(jade.points > ember.points ? .jade : .ember)
            }
        } else if !hasLegalTurn {
            outcome = .victory(mover)
        }
        return true
    }

    func samplingHidden<R: RandomNumberGenerator>(of camp: Camp, using random: inout R) -> Game {
        var sample = self
        let slots = pieces.indices.filter { pieces[$0].camp == camp && !pieces[$0].revealed }
        let revealed = pieces.lazy.filter { $0.camp == camp && $0.revealed && $0.role == .courier }.count
        let left = max(0, Self.couriersPerCamp - tally(for: camp).couriersRemoved - revealed)
        for (position, index) in slots.shuffled(using: &random).enumerated() {
            sample.pieces[index].role = position < left ? .courier : .decoy
        }
        return sample
    }

    @discardableResult
    private mutating func removePiece(at cell: Cell) -> Piece? {
        guard let index = pieces.firstIndex(where: { $0.cell == cell }) else { return nil }
        let piece = pieces.remove(at: index)
        if piece.role == .courier { changeTally(for: piece.camp) { $0.couriersRemoved += 1 } }
        return piece
    }

    private mutating func changeTally(for camp: Camp, _ change: (inout Tally) -> Void) {
        if camp == .jade { change(&jade) } else { change(&ember) }
    }

    private var hasLegalTurn: Bool {
        pieces.contains { piece in
            piece.camp == turn && (canTransmit(at: piece.cell) || !targets(from: piece.cell).isEmpty)
        } || Command.allCases.contains { hasTarget(for: $0) }
    }
}
