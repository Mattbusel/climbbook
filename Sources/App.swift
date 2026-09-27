import SwiftUI

@main
struct ClimbbookApp: App {
    @State private var store: Store
    @State private var router = Router()
    @State private var pro: Pro

    init() {
        let a = ProcessInfo.processInfo.arguments
        let demo = a.contains("-shot") || a.contains("-demoAutoplay")
        _store = State(initialValue: Store(demo: demo))
        let shot = a.firstIndex(of: "-shot").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
        let p: Pro
        if shot == "paywall" { p = Pro(forced: false); p.paywall = .trends }
        else if demo { p = Pro(forced: true) }
        else { p = Pro() }
        _pro = State(initialValue: p)
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(store).environment(router).environment(pro)
                .preferredColorScheme(.light).tint(Ply.send)
                .onAppear { router.applyShotArgs(store); Autopilot.shared.run(store, router, pro) }
        }
    }
}

enum Tab: String, CaseIterable, Identifiable {
    case wall, sessions, pyramid, gear
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wall: return "Wall"
        case .sessions: return "Sessions"
        case .pyramid: return "Pyramid"
        case .gear: return "Gear"
        }
    }
    var icon: String {
        switch self {
        case .wall: return "square.grid.3x3.middle.filled"
        case .sessions: return "calendar"
        case .pyramid: return "triangle.fill"
        case .gear: return "slider.horizontal.3"
        }
    }
}

enum Sheet: Identifiable {
    case log(Climb), climb(UUID), session(String), scale(Scale)
    var id: String {
        switch self {
        case .log(let c): return "log-\(c.id)"
        case .climb(let id): return "climb-\(id)"
        case .session(let id): return "session-\(id)"
        case .scale(let s): return "scale-\(s.id)"
        }
    }
}

@MainActor
@Observable
final class Router {
    var tab: Tab = .wall
    var sheet: Sheet? = nil

    func applyShotArgs(_ s: Store) {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-shot"), i + 1 < a.count else { return }
        switch a[i + 1] {
        case "log": sheet = .log(Demo.draft(s))
        case "climb": if let c = s.db.climbs.last(where: { $0.photo != nil }) { sheet = .climb(c.id) }
        case "pyramid": tab = .pyramid
        case "session": if let first = s.sessions(all: true).first { sheet = .session(first.id) }
        case "grades": tab = .gear
        default: break
        }
    }

    /// A fresh climb: same place and grade as the last one logged today, so a session flows.
    func newClimb(_ s: Store) {
        let last = s.db.climbs.last
        let today = last.map { Calendar.current.isDateInToday($0.date) } ?? false
        var c = Climb(date: Date(), scale: s.db.scale, grade: last?.scale == s.db.scale ? last!.grade : min(3, s.scale.grades.count - 1))
        c.place = today ? (last?.place ?? "") : (s.db.places.first ?? "")
        c.outdoor = today ? (last?.outdoor ?? false) : false
        sheet = .log(c)
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        @Bindable var router = router
        @Bindable var pro = pro
        ZStack(alignment: .bottom) {
            Plywood()
            Group {
                switch router.tab {
                case .wall: WallView()
                case .sessions: SessionsView()
                case .pyramid: PyramidView()
                case .gear: GearView()
                }
            }
            .transition(.opacity)
            HoldBar(selection: $router.tab) { router.newClimb(store) }
        }
        .sheet(item: $router.sheet) { sheet in
            Group {
                switch sheet {
                case .log(let c): LogSheet(climb: c)
                case .climb(let id): ClimbDetail(id: id)
                case .session(let id): SessionDetail(id: id)
                case .scale(let s): ScaleEditor(scale: s)
                }
            }
            .presentationBackground(Ply.wood).presentationCornerRadius(32)
            .environment(store).environment(router).environment(pro)
        }
        .overlay {
            Color.clear.allowsHitTesting(false)
                .sheet(item: $pro.paywall) { why in
                    PaywallView(reason: why).environment(pro).environment(store).presentationBackground(Ply.wood).presentationCornerRadius(32)
                }
        }
    }
}

/// The tab bar: a charcoal volume bolted to the wall, with a big red jug in the middle to log a climb.
struct HoldBar: View {
    @Binding var selection: Tab
    var log: () -> Void
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            item(.wall); item(.sessions)
            Button(action: log) {
                ZStack {
                    HoldShape(seed: 11, lumps: 8).fill(Ply.send)
                        .overlay(HoldShape(seed: 11, lumps: 8).fill(LinearGradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .shadow(color: Ply.send.opacity(0.45), radius: 12, y: 6)
                    Image(systemName: "plus").font(.system(size: 24, weight: .black)).foregroundStyle(.white)
                }
                .frame(width: 70, height: 64)
            }
            .buttonStyle(Press())
            .offset(y: -12)
            .frame(width: 84)
            .accessibilityLabel("Log a climb")
            item(.pyramid); item(.gear)
        }
        .padding(.horizontal, 8).padding(.top, 6).padding(.bottom, 2)
        .background(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Ply.ink)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.25), radius: 18, y: -2)
        }
    }

    func item(_ t: Tab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = t }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if selection == t {
                        HoldShape(seed: (Tab.allCases.firstIndex(of: t) ?? 0) * 13 + 5).fill(Ply.flash).frame(width: 40, height: 34).matchedGeometryEffect(id: "hold", in: ns)
                    }
                    Image(systemName: t.icon).font(.system(size: 17, weight: .bold)).foregroundStyle(selection == t ? Ply.ink : Color.white.opacity(0.55))
                }
                .frame(height: 34)
                Text(t.title).font(.tag(9.5)).foregroundStyle(selection == t ? .white : Color.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity).frame(height: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
