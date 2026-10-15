import SwiftUI

@main
struct BlockdownApp: App {
    @State private var engine = TimerEngine()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationManager.shared.activate()
        #if DEBUG
        // Test hook: `simctl launch <udid> com.utkarsh.blockdown -autostart <seconds>`
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-autostart"), args.indices.contains(idx + 1),
           let seconds = TimeInterval(args[idx + 1]) {
            let engine = _engine.wrappedValue
            if engine.isActive { engine.stop() }
            if engine.phase == .finished { engine.acknowledgeFinished() }
            engine.setPlannedDuration(seconds)
            engine.start()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .tint(Color.blockdownTheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                engine.refresh()
            }
        }
    }
}
