import SwiftUI

/// Home: this month's best send, the rope climbing your grades week by week, and your records.
struct WallView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @State private var range = 12

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center) {
                    Text("Climbbook").font(.wide(30)).foregroundStyle(Ply.ink)
                    Spacer()
                    Tape(Fmt.month(Date()), color: Ply.flash)
                }
                .padding(.top, 8)
                BestSend()
                progression
                stats
                records
                if let s = store.sessions(all: true).first { recent(s) }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }

    var progression: some View {
        let weeks = store.weeks(range)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Tape("Grade progression", color: Ply.ink)
                    Text("Hardest top each week, \(store.scale.name)").font(.text(12)).foregroundStyle(Ply.dim).padding(.top, 4)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach([(12, "12W"), (26, "6M"), (52, "1Y")], id: \.0) { r in
                        Button {
                            if r.0 > 12 && !pro.allow(.trends) { return }
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { range = r.0 }
                        } label: {
                            Text(r.1).font(.tag(10.5)).foregroundStyle(range == r.0 ? .white : Ply.ink2)
                                .padding(.horizontal, 9).frame(height: 28)
                                .background(Capsule().fill(range == r.0 ? Ply.ink : .clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3).background(Capsule().fill(Ply.wood2))
            }
            RopeChart(weeks: weeks, scale: store.scale).frame(height: 240)
        }
        .panel(16, radius: 26)
    }

    var stats: some View {
        let cal = Calendar.current
        let m = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        let month = store.onScale.filter { $0.date >= m }
        let tops = month.filter { $0.outcome.topped }
        let flashes = month.filter { $0.outcome == .flash }.count
        let sessions = Set(month.map { "\(cal.startOfDay(for: $0.date))|\($0.place)" }).count
        return HStack(spacing: 10) {
            stat("\(sessions)", "sessions", Ply.project)
            stat("\(tops.count)", "tops", Ply.send)
            stat(tops.isEmpty ? "–" : "\(Int((Double(flashes) / Double(tops.count) * 100).rounded()))%", "flashed", Ply.flash)
            stat("\(store.streakWeeks)", "week streak", Ply.ok)
        }
    }

    func stat(_ v: String, _ l: String, _ c: Color) -> some View {
        VStack(spacing: 4) {
            Text(v).font(.wide(22)).foregroundStyle(Ply.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(l.uppercased()).font(.tag(8.5)).foregroundStyle(Ply.dim).lineLimit(1).minimumScaleFactor(0.7)
            Capsule().fill(c).frame(width: 18, height: 4)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ply.panel).shadow(color: Color(hex: 0x6B5433, alpha: 0.12), radius: 10, y: 4))
    }

    var records: some View {
        VStack(alignment: .leading, spacing: 12) {
            Tape("Records", color: Ply.send)
            VStack(spacing: 0) {
                record("Hardest send", store.hardestEver, detail: { c in "\(c.outcome.title) · \(Fmt.short(c.date))" })
                Divider().overlay(Ply.line).padding(.leading, 74)
                record("Hardest flash", store.hardestFlash, detail: { c in Fmt.short(c.date) })
                Divider().overlay(Ply.line).padding(.leading, 74)
                record("Longest project", store.hardestProject, detail: { c in "\(c.attempts) attempts · \(Fmt.short(c.date))" })
            }
            .panel(6, radius: 22)
        }
    }

    func record(_ title: String, _ c: Climb?, detail: (Climb) -> String) -> some View {
        Button { if let c { router.sheet = .climb(c.id) } } label: {
            HStack(spacing: 14) {
                if let c { Hold(label: store.label(c), color: store.color(c), size: 50, seed: c.grade + 3) }
                else { HoldShape(seed: 2).fill(Ply.wood2).frame(width: 50, height: 45) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.text(15.5, .bold)).foregroundStyle(Ply.ink)
                    Text(c.map { (($0.name.isEmpty ? "" : "\($0.name) · ") + detail($0)) } ?? "Log a climb to set one").font(.text(12.5)).foregroundStyle(Ply.dim).lineLimit(1)
                }
                Spacer()
                if c != nil { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Ply.dim) }
            }
            .padding(10).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func recent(_ s: Session) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Tape("Last session", color: Ply.project)
            Button { router.sheet = .session(s.id) } label: { SessionCard(session: s) }.buttonStyle(Press())
        }
    }
}

/// The month's best send, big: the hold, the grade, how it went.
struct BestSend: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var pop = false

    var body: some View {
        if let c = store.bestThisMonth {
            Button { router.sheet = .climb(c.id) } label: {
                HStack(spacing: 18) {
                    Hold(label: store.label(c), color: store.color(c), size: 118, seed: c.grade * 7 + 1)
                        .scaleEffect(pop ? 1 : 0.6).rotationEffect(.degrees(pop ? -4 : -30))
                        .overlay(alignment: .topTrailing) {
                            if c.outcome == .flash {
                                Image(systemName: "bolt.fill").font(.system(size: 18, weight: .black)).foregroundStyle(Ply.ink)
                                    .frame(width: 36, height: 36).background(Circle().fill(Ply.flash)).offset(x: 6, y: -6)
                                    .scaleEffect(pop ? 1 : 0.1)
                            }
                        }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BEST SEND\nTHIS MONTH").font(.tag(12)).tracking(1.2).foregroundStyle(Ply.send).lineSpacing(2)
                        Text(c.name.isEmpty ? "\(store.label(c)) \(c.tape.map { Ply.tape[$0 % Ply.tape.count].0.lowercased() } ?? "")".trimmingCharacters(in: .whitespaces) : c.name)
                            .font(.wide(21)).foregroundStyle(Ply.ink).lineLimit(2).minimumScaleFactor(0.7)
                        HStack(spacing: 6) {
                            Image(systemName: c.outcome.icon).font(.system(size: 11, weight: .black))
                            Text(c.outcome == .flash ? "Flashed" : "\(c.attempts) \(c.attempts == 1 ? "go" : "goes")").font(.text(13, .bold))
                        }
                        .foregroundStyle(c.outcome.color == Ply.flash ? Ply.ink : .white)
                        .padding(.horizontal, 10).frame(height: 26).background(Capsule().fill(c.outcome.color))
                        Text("\(Fmt.day(c.date))\(c.place.isEmpty ? "" : " · \(c.place)")").font(.text(12.5)).foregroundStyle(Ply.dim).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Ply.panel)
                        RoundedRectangle(cornerRadius: 28, style: .continuous).fill(RadialGradient(colors: [store.color(c).opacity(0.22), .clear], center: .leading, startRadius: 10, endRadius: 260))
                    }
                    .shadow(color: Color(hex: 0x6B5433, alpha: 0.16), radius: 18, y: 8)
                )
            }
            .buttonStyle(Press())
            .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1)) { pop = true } }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("BEST SEND THIS MONTH").font(.tag(12)).tracking(1.2).foregroundStyle(Ply.send)
                Text("Nothing topped yet this month").font(.wide(20)).foregroundStyle(Ply.ink)
                Text("Hit the red hold after each climb. Grade, how it went, how many goes. Five seconds, then back to the wall.")
                    .font(.text(13.5)).foregroundStyle(Ply.dim).fixedSize(horizontal: false, vertical: true)
                InkButton(title: "Log a climb", icon: "plus", color: Ply.send) { router.newClimb(store) }.padding(.top, 4)
            }
            .panel(18, radius: 28)
        }
    }
}

/// Weekly best grades as holds on a plywood panel, joined by a climbing rope.
struct RopeChart: View {
    let weeks: [Store.Week]
    let scale: Scale

    var body: some View {
        let bests = weeks.compactMap(\.best)
        let lo = max(0, (bests.min() ?? 2) - 1), hi = min(scale.grades.count - 1, max((bests.max() ?? 4) + 1, lo + 3))
        GeometryReader { g in
            let left: CGFloat = 40, W = g.size.width - left - 8, H = g.size.height - 24
            let X: (Int) -> CGFloat = { left + (weeks.count > 1 ? CGFloat($0) / CGFloat(weeks.count - 1) : 0.5) * W }
            let Y: (Int) -> CGFloat = { 10 + (1 - CGFloat($0 - lo) / CGFloat(max(1, hi - lo))) * (H - 20) }
            let pts: [(Int, Int)] = weeks.enumerated().compactMap { i, w in w.best.map { (i, $0) } }
            ZStack(alignment: .topLeading) {
                Plywood(bolts: true).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).padding(.leading, left - 6)
                // Grade rungs.
                ForEach(lo...hi, id: \.self) { gr in
                    Path { p in p.move(to: CGPoint(x: left - 6, y: Y(gr))); p.addLine(to: CGPoint(x: left + W + 8, y: Y(gr))) }
                        .stroke(Ply.ink.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                    Text(scale.label(gr)).font(.tag(10)).foregroundStyle(Ply.ink2).frame(width: left - 10, alignment: .trailing).position(x: (left - 10) / 2, y: Y(gr))
                }
                // The rope.
                if pts.count > 1 {
                    let path = RopeChart.smooth(pts.map { CGPoint(x: X($0.0), y: Y($0.1)) })
                    path.stroke(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)).offset(y: 3)
                    path.stroke(Ply.project, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    path.stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, lineCap: .butt, dash: [4, 5]))
                }
                ForEach(pts, id: \.0) { p in
                    Hold(label: "", color: scale.color(p.1), size: 24, seed: p.0 * 5 + p.1)
                        .position(x: X(p.0), y: Y(p.1))
                }
                if let last = pts.last {
                    Text(scale.label(last.1)).font(.tag(11)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Ply.ink)).position(x: min(X(last.0), left + W - 16), y: Y(last.1) - 24)
                }
                // Week labels.
                ForEach(Array(weeks.enumerated()).filter { $0.offset % max(1, weeks.count / 4) == 0 || $0.offset == weeks.count - 1 }, id: \.offset) { i, w in
                    Text(i == weeks.count - 1 ? "now" : Fmt.short(w.start)).font(.text(10, .semibold)).foregroundStyle(Ply.dim).position(x: X(i), y: H + 14)
                }
                if pts.isEmpty {
                    Text("Your rope starts with your first top.").font(.text(13, .semibold)).foregroundStyle(Ply.ink2)
                        .padding(10).background(Capsule().fill(Ply.panel)).position(x: left + W / 2, y: H / 2)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Grade progression")
    }

    /// Catmull-Rom through the points, so the rope hangs in curves rather than kinks.
    static func smooth(_ p: [CGPoint]) -> Path {
        var path = Path()
        guard let first = p.first else { return path }
        path.move(to: first)
        for i in 0..<(p.count - 1) {
            let p0 = p[max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[min(p.count - 1, i + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }
}
