import Foundation

@main
struct GameChecks {
    static func main() throws {
        var random = SeededRandom()
        let initial = Game(using: &random)
        require(initial.pieces.count == 12, "A match must start with twelve pieces")
        require(Set(initial.pieces.map(\.cell)).count == 12, "Opening squares must be unique")
        require(!initial.legalTurns().isEmpty, "The first player must have a legal turn")

        var opening = initial
        let middle = Cell(row: 3, column: 3)
        let out = Cell(row: 3, column: Game.size)
        require(!opening.play(.barrier(out)) && opening == initial, "Illegal moves must leave state unchanged")
        require(opening.play(.barrier(middle)) && opening.blocked == middle, "A barrier must be placed")
        let reply = opening.legalTurns().first { if case .move = $0 { true } else { false } }!
        require(opening.play(reply) && opening.blocked == nil, "A barrier must expire after its opponent's turn")
        require(!opening.play(.barrier(middle)), "A spent command cannot be used again")

        let neighbor = Cell(row: 4, column: 3)
        let target = Cell(row: 3, column: 3)
        let blueCourier = Piece(camp: .jade, role: .courier, cell: neighbor)
        let orangeBait = Piece(camp: .ember, role: .decoy, cell: target)
        let orangeCourier = Piece(camp: .ember, role: .courier, cell: Cell(row: 1, column: 1))
        var scan = try fixture(from: initial, pieces: [blueCourier, orangeBait, orangeCourier])
        require(scan.play(.scan(target)), "An enemy within two squares can be scanned")
        require(scan.piece(at: target)?.revealed == true && scan.turn == .ember, "Scanning reveals and passes the turn")

        var capture = try fixture(from: initial, pieces: [blueCourier, orangeBait, orangeCourier])
        require(capture.play(.move(from: neighbor, to: target, jump: false)), "An orthogonal capture must work")
        require(capture.jade.points == 0 && capture.ember.points == 1, "Capturing a decoy scores for its owner")
        require(capture.piece(at: target)?.camp == .jade, "The capturing piece must replace the captured piece")

        let relayCourier = Piece(camp: .jade, role: .courier, cell: Camp.jade.relay)
        var transmission = try fixture(from: initial, pieces: [relayCourier, orangeCourier], jade: Tally(points: 3))
        require(transmission.play(.transmit(Camp.jade.relay)), "A courier on the enemy relay can transmit")
        require(transmission.jade.points == 5 && transmission.jade.couriersRemoved == 1
                && transmission.outcome == .victory(.jade), "A transmission must score two and check for victory")
        let encoded = try JSONEncoder().encode(transmission)
        let decoded = try JSONDecoder().decode(Game.self, from: encoded)
        require(decoded == transmission, "A replay snapshot must round-trip")

        var reversed = initial.pieces
        let first = reversed.firstIndex { $0.camp == .ember && $0.role == .courier }!
        let second = reversed.firstIndex { $0.camp == .ember && $0.role == .decoy }!
        reversed[first].role = .decoy
        reversed[second].role = .courier
        let alternate = try fixture(from: initial, pieces: reversed)
        var seedA = SeededRandom()
        var seedB = SeededRandom()
        let normal = Opponent.choose(in: initial, difficulty: .standard, using: &seedA)
        let swapped = Opponent.choose(in: alternate, difficulty: .standard, using: &seedB)
        require(normal == swapped && normal.map(initial.legalTurns().contains) == true,
                "The AI choice must be legal and independent of the hidden ground truth")
        let expert = Opponent.choose(in: initial, difficulty: .expert, using: &random)
        require(expert.map(initial.legalTurns().contains) == true, "Expert AI must choose a legal turn")

        print("Game checks passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
    }

    private static func fixture(from game: Game, pieces: [Piece], jade: Tally = Tally()) throws -> Game {
        let encoder = JSONEncoder()
        var object = try JSONSerialization.jsonObject(with: encoder.encode(game)) as! [String: Any]
        object["pieces"] = try JSONSerialization.jsonObject(with: encoder.encode(pieces))
        object["jade"] = try JSONSerialization.jsonObject(with: encoder.encode(jade))
        return try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: object))
    }
}

private struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64 = 17

    mutating func next() -> UInt64 {
        state = state &* 2_862_933_555_777_941_757 &+ 3_037_000_493
        return state
    }
}
