# 讯阵

基于 SwiftUI 的离线隐藏身份策略棋局，支持 iOS 17 及更新版本的 iPhone 和 iPad。

- **人机对战**有三档难度。AI 按公开信息推测敌方棋子身份。
- **本地双人**在每手之间遮蔽棋盘。下一位玩家确认后可查看己方身份。
- **存档和回放**会恢复未完成的对局，并支持逐手查看已完成的对局、分享棋谱。

## 从 APK 确认的内容

| 项目 | 静态解析结果 |
| --- | --- |
| APK | Android 包名 com.rainet.ai，版本 0.1（构建号 1） |
| 运行环境 | Unity 2022.3.62f3，IL2CPP，Android ARM64，最低 API 22，目标 API 36 |
| 游戏数据 | 一个 Unity 主场景、序列化资源以及 Assembly-CSharp 的 IL2CPP 元数据 |
| 功能线索 | 隐藏身份棋局、终端卡、AI 难度、对局历史和导出，以及联机房间和账户 |

讯阵采用独立的 7 × 7 棋盘、计分、指令和视觉设计。原 APK、提取的素材和服务端配置均保留在公开源码之外。APK 中的账号、联机、积分以及旧版 AI 和旧存档兼容性不在这次离线重构的范围内。

## 编译和安装

主分支提交会触发 [Build iOS](https://github.com/hahahalucas/rainet-ios/actions/workflows/ios.yml)，也可在同一页面手动运行。成功后，在该次运行的 **Artifacts** 下载 **SignalGrid-unsigned-ipa** 并解压，里面是 **SignalGrid-unsigned.ipa**。标准 macOS runner 在公开仓库中的计算用量免费。[GitHub Actions 计费说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)

直接安装真机需要 Apple 签名。用 Mac 上的 Xcode 打开 SignalGrid.xcodeproj，为 SignalGrid target 选择自己的 Signing & Capabilities 团队和已注册的 Bundle Identifier，再归档并选择 **Release Testing** 或 **Debugging** 导出签名 IPA。[Apple 真机分发说明](https://developer.apple.com/documentation/xcode/distributing-apps-to-your-development-devices)

## 源码

- **Game.swift / Opponent.swift** 负责走棋、计分、隐藏状态和 AI。
- **MatchStore.swift** 管理当前对局、回放帧和本地存档。
- **SignalGridApp.swift** 及各 View 提供原生界面。
- **Tests/GameChecks.swift** 在 CI 中验证规则、存档格式和 AI 对隐藏信息的处理。
