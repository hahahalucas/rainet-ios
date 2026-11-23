import Foundation
import SwiftUI

enum MatchMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case solo, local

    var id: Self { self }
    var title: String { self == .solo ? "人机对战" : "本地双人" }
    var symbol: String { self == .solo ? "cpu" : "person.2" }
}

struct MatchRecord: Identifiable, Codable, Sendable {
    let id: UUID
    let startedAt: Date
    let mode: MatchMode
    let difficulty: Difficulty
    private(set) var frames: [Game]

    var game: Game { frames[frames.count - 1] }
    var detail: String { mode == .solo ? "\(mode.title) · \(difficulty.name)" : mode.title }

    init(mode: MatchMode, difficulty: Difficulty, initial: Game) {
        id = UUID()
        startedAt = Date()
        self.mode = mode
        self.difficulty = difficulty
        frames = [initial]
    }

    mutating func play(_ action: Turn) -> Bool {
        var next = game
        guard next.play(action) else { return false }
        frames.append(next)
        return true
    }
}

private struct MatchArchive: Codable {
    var version = 1
    var active: MatchRecord?
    var completed: [MatchRecord] = []
}

@MainActor
final class MatchStore: ObservableObject {
    @Published private(set) var current: MatchRecord?
    @Published private(set) var completed: [MatchRecord] = []
    @Published private(set) var storageMessage: String?
    private let archiveURL: URL
    private var maySave = true

    var hasUnfinishedMatch: Bool { current.map { $0.game.outcome == nil } ?? false }

    init() {
        archiveURL = URL.applicationSupportDirectory
            .appending(path: "SignalGrid", directoryHint: .isDirectory)
            .appending(path: "matches.json")
        guard FileManager.default.fileExists(atPath: archiveURL.path) else { return }
        do {
            let archive = try JSONDecoder().decode(MatchArchive.self, from: Data(contentsOf: archiveURL))
            guard archive.version == 1,
                  archive.active.map({ !$0.frames.isEmpty && $0.game.outcome == nil }) ?? true,
                  archive.completed.allSatisfy({ !$0.frames.isEmpty && $0.game.outcome != nil }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            current = archive.active
            completed = archive.completed
        } catch {
            maySave = false
            storageMessage = "无法读取已有存档。本次对局仅保留在当前会话中。"
        }
    }

    func start(mode: MatchMode, difficulty: Difficulty) {
        var random = SystemRandomNumberGenerator()
        current = MatchRecord(mode: mode, difficulty: difficulty, initial: Game(using: &random))
        save()
    }

    func play(_ action: Turn, in matchID: UUID, ply: Int) {
        guard var match = current, match.id == matchID, match.game.ply == ply, match.play(action) else {
            return
        }
        current = match
        if match.game.outcome != nil { completed.insert(match, at: 0) }
        save()
    }

    func playOpponent(in matchID: UUID, ply: Int) async {
        guard !Task.isCancelled, let match = current, match.id == matchID, match.game.ply == ply,
              match.mode == .solo, match.game.turn == .ember, match.game.outcome == nil else { return }

        let search = Task.detached(priority: .userInitiated) {
            Opponent.choose(in: match.game, difficulty: match.difficulty)
        }
        let action = await withTaskCancellationHandler {
            await search.value
        } onCancel: {
            search.cancel()
        }
        guard !Task.isCancelled, let action else { return }
        play(action, in: matchID, ply: ply)
    }

    private func save() {
        guard maySave else { return }
        let archive = MatchArchive(active: hasUnfinishedMatch ? current : nil, completed: completed)
        do {
            try FileManager.default.createDirectory(
                at: archiveURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(archive)
            try data.write(to: archiveURL, options: .atomic)
            storageMessage = nil
        } catch {
            storageMessage = "保存失败。本次对局仍可继续。"
        }
    }
}
