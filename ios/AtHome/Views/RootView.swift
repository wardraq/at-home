import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            if appModel.isPaired {
                NavigationStack {
                    HomeView()
                }
            } else {
                UnpairedView()
            }
        }
        .task {
            #if DEBUG
            if appModel.pairing != nil && !appModel.isPaired {
                _ = try? await appModel.testConnection()
            }
            if appModel.isPaired {
                await appModel.syncEngine.refreshStats()
                // 模拟器调试：启动后自动同步一次
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await appModel.syncEngine.sync()
                }
            }
            #else
            if appModel.isPaired {
                await appModel.syncEngine.refreshStats()
            }
            #endif
        }
    }
}
