import SwiftUI

/// Drives the real screens for the App Review recording (-demoAutoplay).
@MainActor
final class Autopilot {
    static let shared = Autopilot()
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demoAutoplay") }
    private var running = false
    private func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }

    func run(_ store: Store, _ router: Router, _ pro: Pro) {
        guard Autopilot.on, !running else { return }
        running = true
        Task { @MainActor in
            await wait(4.5)
            router.sheet = .log(Demo.draft(store)); await wait(5)
            router.sheet = nil; await wait(1.2)
            if let c = store.bestThisMonth { router.sheet = .climb(c.id); await wait(4); router.sheet = nil; await wait(1.2) }
            withAnimation { router.tab = .sessions }; await wait(3)
            if let s = store.sessions(all: true).first { router.sheet = .session(s.id); await wait(4); router.sheet = nil; await wait(1.2) }
            withAnimation { router.tab = .pyramid }; await wait(4)
            withAnimation { router.tab = .gear }; await wait(3.5)
            withAnimation { router.tab = .wall }; await wait(1.5)
            pro.paywall = .settings; await wait(5)
            pro.paywall = nil; await wait(1.5)
            try? Data("ok".utf8).write(to: URL.documentsDirectory.appending(path: "demo_done"))
        }
    }
}
