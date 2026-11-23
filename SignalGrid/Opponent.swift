import Foundation

enum Difficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case casual, standard, expert

    var id: Self { self }

    var name: String {
        switch self {
        case .casual: "轻松"
        case .standard: "标准"
        case .expert: "高手"
        }
    }

    var settings: (samples: Int, depth: Int, beam: Int, variety: Double) {
        switch self {
        case .casual: (2, 1, 1, 3.0)
        case .standard: (4, 2, 5, 0.45)
        case .expert: (7, 3, 6, 0.08)
        }
    }
}

enum Opponent {
    static func choose(in game: Game, difficulty: Difficulty) -> Turn? {
        var random = SystemRandomNumberGenerator()
        return choose(in: game, difficulty: difficulty, using: &random)
    }

    static func choose<R: RandomNumberGenerator>(
        in game: Game, difficulty: Difficulty, using random: inout R
    ) -> Turn? {
        let camp = game.turn
        let settings = difficulty.settings
        let choices = game.legalTurns()
        guard !choices.isEmpty else { return nil }
        let samples = (0..<settings.samples).map { _ in
            game.samplingHidden(of: camp.opponent, using: &random)
        }

        var best: Turn?
        var bestScore = -Double.infinity
        for action in choices {
            if Task.isCancelled { return nil }
            var total = 0.0
            for var sample in samples {
                guard sample.play(action) else { continue }
                total += evaluateTurn(sample, for: camp, depth: settings.depth - 1, beam: settings.beam)
            }
            let noise = Double.random(in: 0...settings.variety, using: &random)
            let score = total / Double(samples.count) + noise
            if score > bestScore {
                bestScore = score
                best = action
            }
        }
        return best
    }

    private static func evaluateTurn(_ game: Game, for camp: Camp, depth: Int, beam: Int) -> Double {
        let immediate = score(game, for: camp)
        guard depth > 0, game.outcome == nil, !Task.isCancelled else { return immediate }
        let maximizing = game.turn == camp
        let replies = game.legalTurns().compactMap { action -> (Game, Double)? in
            var next = game
            guard next.play(action) else { return nil }
            return (next, score(next, for: camp))
        }.sorted { maximizing ? $0.1 > $1.1 : $0.1 < $1.1 }

        guard let first = replies.first else { return immediate }
        if depth == 1 { return first.1 }

        var result = maximizing ? -Double.infinity : Double.infinity
        for (next, _) in replies.prefix(beam) {
            let value = evaluateTurn(next, for: camp, depth: depth - 1, beam: beam)
            result = maximizing ? max(result, value) : min(result, value)
        }
        return result
    }

    private static func score(_ game: Game, for camp: Camp) -> Double {
        if let outcome = game.outcome {
            switch outcome {
            case .draw: return 0
            case .victory(let winner):
                let preference = Double(1000 - game.ply)
                return winner == camp ? preference : -preference
            }
        }

        var value = Double(game.tally(for: camp).points - game.tally(for: camp.opponent).points) * 8
        value += Double(game.tally(for: camp.opponent).used.count - game.tally(for: camp).used.count) * 0.4
        for piece in game.pieces {
            let direction = piece.camp == camp ? 1.0 : -1.0
            if piece.role == .courier {
                let distance = piece.cell.distance(to: piece.camp.relay)
                value += direction * (2.5 - Double(distance) * 0.48 - (piece.revealed ? 0.75 : 0))
            } else {
                let advance = piece.camp == .jade ? Game.size - 1 - piece.cell.row : piece.cell.row
                value += direction * (0.16 * Double(advance) + (piece.revealed ? 0 : 0.38))
            }
        }
        return value
    }
}
