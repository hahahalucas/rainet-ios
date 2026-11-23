import SwiftUI

struct ReplayView: View {
    let record: MatchRecord
    @State private var index = 0

    private var lastIndex: Int { record.frames.count - 1 }

    var body: some View {
        let game = record.frames[index]
        Screen {
            VStack(alignment: .leading, spacing: 15) {
                ScoresView(game: game)
                BoardView(game: game, perspective: .everyone)
                Text(game.event).font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)

                VStack(spacing: 9) {
                    HStack {
                        Button("上一步", systemImage: "chevron.left") { index -= 1 }
                            .disabled(index == 0)
                        Spacer()
                        Text("\(index) / \(lastIndex)").font(.subheadline.monospacedDigit())
                            .foregroundStyle(Palette.secondary)
                        Spacer()
                        Button("下一步", systemImage: "chevron.right") { index += 1 }
                            .disabled(index == lastIndex)
                    }
                    .font(.subheadline.bold())
                    .buttonStyle(.bordered)
                    if lastIndex > 0 {
                        Slider(
                            value: Binding(get: { Double(index) }, set: { index = Int($0.rounded()) }),
                            in: 0...Double(lastIndex), step: 1
                        ) { Text("回放进度") }
                    }
                }
                .padding(13)
                .modifier(Panel())
            }
        }
        .navigationTitle("对局回放")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ShareLink(item: moveLog) {
                Label("分享棋谱", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var moveLog: String {
        let header = "讯阵 · \(record.detail) · \(record.game.outcome?.title ?? "")"
        let moves = record.frames.map { "\($0.ply)  \($0.event)" }
        return ([header] + moves).joined(separator: "\n")
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Screen {
                VStack(alignment: .leading, spacing: 17) {
                    rule("开局", "每方有 3 枚信使和 3 枚诱饵。双方身份随机布置，行动方可以查看己方的身份。")
                    rule("走棋", "每手移动一枚棋子，上下左右走一格。走到敌棋所在格会捕获它。抓到信使，己方加 1 分。抓到诱饵，对方加 1 分。")
                    rule("信号传输", "把信使走到对面底线中央的中继点，之后可选中信使并传输。传输消耗一手，信使离场，己方加 2 分。")
                    rule("指令", "每项指令每方可用一次，消耗一手。侦察可翻开距己方棋子两格以内的敌棋。跃迁需跨过一个空格，落到同一直线上的空格。阻断可封住棋盘中间三行的任一空格，持续到对手下一手结束。")
                    rule("胜负", "先得 5 分的一方获胜。轮到一方时，棋子全失或无合法行动则落败。走满 80 手后按分数决胜，同分为平局。")
                }
            }
            .navigationTitle("游戏规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("完成") { dismiss() } }
        }
        .preferredColorScheme(.dark)
    }

    private func rule(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(description).font(.subheadline).foregroundStyle(Palette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .modifier(Panel())
    }
}
