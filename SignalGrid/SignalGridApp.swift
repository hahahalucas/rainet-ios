import SwiftUI

enum Palette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.075)
    static let panel = Color(red: 0.063, green: 0.097, blue: 0.132)
    static let border = Color(red: 0.14, green: 0.21, blue: 0.27)
    static let foreground = Color(red: 0.91, green: 0.96, blue: 0.98)
    static let secondary = Color(red: 0.58, green: 0.67, blue: 0.73)
    static let jade = Color(red: 0.47, green: 0.94, blue: 0.76)
    static let ember = Color(red: 1, green: 0.67, blue: 0.39)
}

extension Camp {
    var color: Color { self == .jade ? Palette.jade : Palette.ember }
}

extension Command {
    var symbol: String {
        switch self {
        case .scan: "scope"
        case .jump: "arrow.up.right"
        case .barrier: "lock"
        }
    }
}

struct Panel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 12)
            .foregroundStyle(Palette.background)
            .background(Palette.jade, in: RoundedRectangle(cornerRadius: 13))
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.4)
    }
}

struct Screen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
        }
        .background(Palette.background.ignoresSafeArea())
        .foregroundStyle(Palette.foreground)
    }
}

@main
struct SignalGridApp: App {
    @StateObject private var store = MatchStore()

    var body: some Scene {
        WindowGroup {
            HomeView(store: store)
                .preferredColorScheme(.dark)
                .tint(Palette.jade)
        }
    }
}

enum Route: Hashable {
    case match
    case replay(UUID)
}

struct HomeView: View {
    @ObservedObject var store: MatchStore
    @AppStorage("matchMode") private var mode = MatchMode.solo
    @AppStorage("difficulty") private var difficulty = Difficulty.standard
    @State private var path: [Route] = []
    @State private var showRules = false
    @State private var replaceMatch = false

    var body: some View {
        NavigationStack(path: $path) {
            Screen {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    setup
                    if let message = store.storageMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(Palette.ember)
                    }
                    history
                }
            }
            .navigationTitle("讯阵")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("规则", systemImage: "questionmark.circle") { showRules = true }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .match:
                    MatchView(store: store)
                case .replay(let id):
                    if let record = store.completed.first(where: { $0.id == id }) {
                        ReplayView(record: record)
                    }
                }
            }
            .sheet(isPresented: $showRules) { RulesView() }
            .confirmationDialog("开始新对局？", isPresented: $replaceMatch, titleVisibility: .visible) {
                Button("开始新对局", role: .destructive, action: start)
            } message: {
                Text("当前未完成的对局将被替换。")
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(Palette.jade)
                .accessibilityHidden(true)
            Text("讯阵").font(.system(.largeTitle, design: .rounded, weight: .semibold))
            Text("隐匿身份，夺取中继点。").font(.subheadline).foregroundStyle(Palette.secondary)
        }
        .padding(21)
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .background {
            Canvas { context, size in
                let radius = min(size.width * 0.31, 116)
                let center = CGPoint(x: size.width * 0.86, y: size.height * 0.54)
                for fraction in [0.44, 0.71, 0.98, 1.25] {
                    let distance = radius * fraction
                    let rect = CGRect(x: center.x - distance, y: center.y - distance,
                                      width: distance * 2, height: distance * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(Palette.jade.opacity(0.19)), lineWidth: 1)
                }
                for (dx, dy) in [(-0.64, -0.30), (-0.32, 0.30), (0.24, -0.37), (0.52, 0.48)] {
                    let dot = CGRect(x: center.x + radius * dx - 3, y: center.y + radius * dy - 3,
                                     width: 6, height: 6)
                    context.fill(Path(ellipseIn: dot), with: .color(Palette.jade.opacity(0.66)))
                }
            }
            .accessibilityHidden(true)
        }
        .background {
            LinearGradient(colors: [Palette.panel, Palette.jade.opacity(0.14)],
                           startPoint: .bottomLeading, endPoint: .topTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.border, lineWidth: 1) }
    }

    private var setup: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("对局设置").font(.title3.bold())
            Picker("对战模式", selection: $mode) {
                ForEach(MatchMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            if mode == .solo {
                HStack {
                    Label("AI 难度", systemImage: "cpu")
                    Spacer()
                    Picker("AI 难度", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { Text($0.name).tag($0) }
                    }
                    .labelsHidden()
                }
                .font(.subheadline)
            }

            if store.hasUnfinishedMatch {
                Button("继续对局") { path.append(.match) }.buttonStyle(PrimaryButton())
            }
            Button {
                if store.hasUnfinishedMatch { replaceMatch = true } else { start() }
            } label: {
                Label("开始新对局", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButton())
            .brightness(store.hasUnfinishedMatch ? -0.1 : 0)
        }
        .padding(17)
        .modifier(Panel())
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("对局回放").font(.title3.bold())
            if store.completed.isEmpty {
                Text("完成首局后可在这里复盘。")
                    .font(.subheadline).foregroundStyle(Palette.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(Panel())
            } else {
                ForEach(store.completed) { match in
                    NavigationLink(value: Route.replay(match.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: match.mode.symbol)
                                .foregroundStyle(Palette.jade).frame(width: 26)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(match.game.outcome?.title ?? match.detail).font(.headline)
                                Text("\(match.detail) · \(match.game.ply) 手")
                                    .font(.subheadline).foregroundStyle(Palette.secondary)
                                Text(match.startedAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption).foregroundStyle(Palette.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold()).foregroundStyle(Palette.secondary)
                                .accessibilityHidden(true)
                        }
                        .padding(15)
                        .modifier(Panel())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func start() {
        store.start(mode: mode, difficulty: difficulty)
        path.append(.match)
    }
}
