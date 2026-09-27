import SwiftUI

/// A problem set up the wall: holds getting harder, a rope climbing them, and a gold top hold marked PRO.
struct PaywallView: View {
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    let reason: Pro.Reason
    @State private var climb: CGFloat = 0

    var body: some View {
        ZStack {
            Plywood()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Tape("Climbbook Pro", color: Ply.send)
                        Spacer()
                        CloseKnob { dismiss() }
                    }
                    problem.frame(height: 250)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(headline).font(.wide(28)).foregroundStyle(Ply.ink).fixedSize(horizontal: false, vertical: true)
                        Text("Logging, sessions, records and your last 60 days stay free. Pro is the whole climbing life.")
                            .font(.text(14.5)).foregroundStyle(Ply.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        feature("clock.arrow.circlepath", Ply.project, "Every session, forever", "Your whole history, back to the first climb you logged.")
                        feature("chart.line.uptrend.xyaxis", Ply.send, "Trends", "Progression over 6 months or a year, the pyramid over any range, styles and flash rates.")
                        feature("camera.fill", Ply.ok, "Photos", "A picture of the problem with every climb, for the beta and the memory.")
                        feature("paintpalette.fill", Ply.flash, "Your gym's grades", "Circuit colours or numbers: build the system your gym uses.")
                        feature("square.and.arrow.up.fill", Ply.ink2, "Export", "Every climb as a spreadsheet.")
                    }
                    .panel(18, radius: 26)
                    VStack(spacing: 4) {
                        Text(pro.price).font(.wide(40)).foregroundStyle(Ply.ink)
                        Text("ONCE · NO SUBSCRIPTION · FAMILY SHARING").font(.tag(10.5)).foregroundStyle(Ply.dim)
                    }
                    .frame(maxWidth: .infinity)
                    if let m = pro.message {
                        Text(m).font(.text(13, .semibold)).foregroundStyle(Ply.send).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                    InkButton(title: pro.busy ? "One moment" : "Unlock Pro for \(pro.price)", icon: "lock.open.fill", color: Ply.send) { Task { await pro.buy() } }
                        .disabled(pro.busy)
                    HStack(spacing: 10) {
                        SoftButton(title: "Restore purchase", icon: "arrow.clockwise") { Task { await pro.restore() } }
                        SoftButton(title: "Not now") { dismiss() }
                    }
                    Text("Every climb you log is kept, Pro or not.").font(.text(11.5)).foregroundStyle(Ply.dim)
                }
                .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 40)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.6).delay(0.2)) { climb = 1 } }
        .onChange(of: pro.unlocked) { _, now in if now { dismiss() } }
    }

    var headline: String {
        switch reason {
        case .trends: return "See the whole climb, not just this week."
        case .history: return "Every session you've ever logged."
        case .photos: return "Keep a photo of every problem."
        case .grades: return "Grade the way your gym does."
        case .export: return "Take your climbs anywhere."
        case .settings: return "Top out."
        }
    }

    var problem: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let pts: [CGPoint] = [CGPoint(x: 0.18, y: 0.9), CGPoint(x: 0.38, y: 0.74), CGPoint(x: 0.26, y: 0.55), CGPoint(x: 0.52, y: 0.42), CGPoint(x: 0.44, y: 0.24), CGPoint(x: 0.7, y: 0.1)]
                .map { CGPoint(x: $0.x * W, y: $0.y * H) }
            ZStack {
                RopeChart.smooth(pts).trim(from: 0, to: climb)
                    .stroke(Ply.project, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                RopeChart.smooth(pts).trim(from: 0, to: climb)
                    .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 2.2, dash: [4, 5]))
                ForEach(0..<5, id: \.self) { i in
                    Hold(label: "", color: Ply.circuit[i * 2 % Ply.circuit.count], size: 40 + CGFloat(i) * 2, seed: i * 17 + 4).position(pts[i])
                }
                Hold(label: "PRO", color: Ply.flash, size: 96, seed: 77).position(pts[5])
                    .scaleEffect(climb > 0.95 ? 1.08 : 1)
                    .shadow(color: Ply.flash.opacity(0.6), radius: climb > 0.95 ? 20 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(1.7), value: climb)
            }
        }
    }

    func feature(_ icon: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(tint == Ply.flash ? Ply.ink : tint)
                .frame(width: 40, height: 40).background(HoldShape(seed: title.count).fill(tint.opacity(0.22)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.text(15.5, .bold)).foregroundStyle(Ply.ink)
                Text(detail).font(.text(12.5)).foregroundStyle(Ply.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ProCard: View {
    @Environment(Pro.self) private var pro
    var body: some View {
        if pro.unlocked {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(Ply.ok)
                Text("Climbbook Pro is unlocked. Climb on.").font(.text(14.5, .bold)).foregroundStyle(Ply.ink)
                Spacer()
            }
            .panel(14, radius: 20)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Hold(label: "PRO", color: Ply.flash, size: 56, seed: 77)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Climbbook Pro").font(.wide(18)).foregroundStyle(Ply.ink)
                        Text("Whole history, trends, photos, your gym's grades and export. \(pro.price) once.")
                            .font(.text(12.5)).foregroundStyle(Ply.dim).fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 10) {
                    SoftButton(title: "See Pro", icon: "sparkles", tint: Ply.send) { pro.paywall = .settings }
                    SoftButton(title: "Restore", icon: "arrow.clockwise") { Task { await pro.restore() } }
                }
                if let m = pro.message, pro.paywall == nil { Text(m).font(.text(12, .semibold)).foregroundStyle(Ply.send) }
            }
            .panel(16, radius: 24)
        }
    }
}
