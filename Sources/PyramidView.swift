import SwiftUI

/// The grade pyramid: every top as a hold, stacked by grade. A wide base under a narrow
/// peak is what steady progress looks like.
struct PyramidView: View {
    @Environment(Store.self) private var store
    @Environment(Pro.self) private var pro
    @State private var range = 0
    static let ranges: [(String, Int?)] = [("Month", 30), ("3 months", 91), ("Year", 365), ("All", nil)]

    var body: some View {
        let days = PyramidView.ranges[range].1
        let since = days.map { Date().addingTimeInterval(-Double($0) * 86400) }
        let rows = store.pyramid(since: since)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Pyramid").font(.wide(30)).foregroundStyle(Ply.ink).padding(.top, 8)
                HStack(spacing: 2) {
                    ForEach(PyramidView.ranges.indices, id: \.self) { i in
                        Button {
                            if i > 0 && !pro.allow(.trends) { return }
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { range = i }
                        } label: {
                            HStack(spacing: 4) {
                                if i > 0 && !pro.unlocked { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)) }
                                Text(PyramidView.ranges[i].0).font(.text(13, .bold))
                            }
                            .foregroundStyle(range == i ? .white : Ply.ink2)
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background(Capsule().fill(range == i ? Ply.ink : .clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3).background(Capsule().fill(Ply.wood2))
                .sensoryFeedback(.selection, trigger: range)

                VStack(spacing: 6) {
                    if rows.isEmpty {
                        Text("Top a climb and it lands here.").font(.text(14, .semibold)).foregroundStyle(Ply.dim).frame(maxWidth: .infinity).padding(.vertical, 50)
                    }
                    ForEach(rows.reversed(), id: \.grade) { r in
                        row(r.grade, flash: r.flash, send: r.send, widest: rows.map { $0.flash + $0.send }.max() ?? 1)
                    }
                }
                .padding(.vertical, 18).padding(.horizontal, 10)
                .background(Plywood().clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous)))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Ply.line))
                .id(range)
                .transition(.opacity)

                HStack(spacing: 16) {
                    legend(true, "Flash")
                    legend(false, "Send or repeat")
                    Spacer()
                    Text("\(rows.reduce(0) { $0 + $1.flash + $1.send }) tops").font(.text(12.5, .bold)).foregroundStyle(Ply.dim)
                }
                if pro.unlocked { StyleBreakdown(since: since) } else { lockedStyles }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }

    func row(_ g: Int, flash: Int, send: Int, widest: Int) -> some View {
        let total = flash + send
        let shown = min(total, 14)
        return HStack(spacing: 8) {
            Text(store.scale.label(g)).font(.tag(11)).foregroundStyle(Ply.ink).frame(width: 40, alignment: .trailing)
            HStack(spacing: -4) {
                ForEach(0..<shown, id: \.self) { i in
                    Hold(label: "", color: store.scale.color(g), size: 26, seed: g * 31 + i)
                        .overlay(HoldShape(seed: g * 31 + i).stroke(i < flash ? Ply.ink : .clear, lineWidth: 2.5).frame(width: 26, height: 23.4))
                }
                if total > shown { Text("+\(total - shown)").font(.tag(10)).foregroundStyle(Ply.ink2).padding(.leading, 8) }
            }
            .frame(maxWidth: .infinity)
            Text("\(total)").font(.tag(11)).foregroundStyle(Ply.dim).frame(width: 26, alignment: .leading)
        }
        .frame(height: 28)
    }

    func legend(_ ring: Bool, _ t: String) -> some View {
        HStack(spacing: 6) {
            HoldShape(seed: 3).fill(Ply.dim.opacity(0.5)).overlay(HoldShape(seed: 3).stroke(ring ? Ply.ink : .clear, lineWidth: 2)).frame(width: 16, height: 14)
            Text(t).font(.text(12, .semibold)).foregroundStyle(Ply.ink2)
        }
    }

    var lockedStyles: some View {
        Button { pro.paywall = .trends } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Tape("What you climb", color: Ply.project)
                    Spacer()
                    Image(systemName: "lock.fill").foregroundStyle(Ply.send)
                }
                Text("See which styles you send and which you avoid, flash rates by grade, and gym versus outside. Plus the pyramid over any range, with Climbbook Pro.")
                    .font(.text(13.5)).foregroundStyle(Ply.dim).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            .panel(16, radius: 22)
        }
        .buttonStyle(Press())
    }
}

/// Which styles you top, as coloured tape lengths; and your flash rate at each grade.
struct StyleBreakdown: View {
    @Environment(Store.self) private var store
    let since: Date?
    var body: some View {
        let cs = store.onScale.filter { since == nil || $0.date >= since! }
        let tops = cs.filter { $0.outcome.topped }
        var counts: [String: Int] = [:]
        for c in tops { for t in c.tags { counts[t, default: 0] += 1 } }
        let styles = counts.sorted { $0.value > $1.value }.prefix(7)
        let top = styles.first?.value ?? 1
        let grades = Set(cs.map(\.grade)).sorted().suffix(5)
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Tape("What you climb", color: Ply.project)
                if styles.isEmpty { Text("Tag climbs with a style (crimpy, slab, overhang…) to see this.").font(.text(13)).foregroundStyle(Ply.dim) }
                ForEach(Array(styles.enumerated()), id: \.element.key) { i, kv in
                    HStack(spacing: 10) {
                        Text(kv.key).font(.text(13.5, .bold)).foregroundStyle(Ply.ink).frame(width: 96, alignment: .leading)
                        GeometryReader { g in
                            TornTape().fill(Ply.tape[(i * 3 + 1) % Ply.tape.count].1)
                                .frame(width: max(20, g.size.width * CGFloat(kv.value) / CGFloat(top)))
                        }
                        .frame(height: 18)
                        Text("\(kv.value)").font(.tag(11)).foregroundStyle(Ply.dim).frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .panel(16, radius: 22)
            VStack(alignment: .leading, spacing: 12) {
                Tape("Flash rate", color: Ply.flash)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(grades), id: \.self) { g in
                        let at = cs.filter { $0.grade == g }
                        let rate = at.isEmpty ? 0 : Double(at.filter { $0.outcome == .flash }.count) / Double(at.count)
                        VStack(spacing: 6) {
                            Text("\(Int((rate * 100).rounded()))%").font(.tag(10.5)).foregroundStyle(Ply.ink)
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Ply.flash).frame(height: max(6, 110 * rate))
                            Hold(label: store.scale.label(g), color: store.scale.color(g), size: 38, seed: g)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 180, alignment: .bottom)
            }
            .panel(16, radius: 22)
        }
    }
}
