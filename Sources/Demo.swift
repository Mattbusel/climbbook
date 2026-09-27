import SwiftUI

/// Twenty weeks of bouldering for screenshots and the review recording. Never saved.
@MainActor
enum Demo {
    static func fill(_ s: Store) {
        var seed: UInt64 = 42
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let places = ["Crux Yard", "Crux Yard", "Sandbag Boulders", "Crux Yard"]
        let styles = LogSheet.tags
        let names = ["Purple cave traverse", "The Prow", "Slab of doom", "Crimp city", "Blue arete", "Pinch me", "Dyno to the jug", "Heel hook heaven", "Sloper sadness", "The mantle"]
        var climbs: [Climb] = []
        // Sessions every 3-4 days, getting a grade stronger across twenty weeks.
        var day = -140
        var n = 0
        while day <= 0 {
            let progress = Double(day + 140) / 140
            let peak = 3 + Int((progress * 3.2).rounded(.down))   // V3 -> V6 (indices 4 -> 7)
            let place = day > -40 && n % 5 == 2 ? "Joe's Valley" : places[n % places.count]
            let outdoor = place == "Joe's Valley"
            let count = 7 + Int(rnd() * 6)
            var t = today.addingTimeInterval(TimeInterval(day) * 86400 + (18 + rnd() * 1.5) * 3600)
            for k in 0..<count {
                var g = peak + 1 - Int(rnd() * 5)                       // warm-ups to limit
                if k < 2 { g = max(1, peak - 3 + k) }
                if k == count - 1 && rnd() < 0.3 { g = peak + 2 }        // a try at a project
                g = max(1, min(g, 11))
                let hard = g - peak
                var o: Outcome
                var att: Int
                switch hard {
                case ...(-2): o = rnd() < 0.8 ? .flash : .repeat_; att = 1
                case -1: o = rnd() < 0.45 ? .flash : .send; att = o == .flash ? 1 : 2 + Int(rnd() * 2)
                case 0: o = rnd() < 0.55 ? .send : (rnd() < 0.2 ? .flash : .project); att = o == .flash ? 1 : 2 + Int(rnd() * 5)
                default: o = rnd() < 0.2 ? .send : .project; att = 3 + Int(rnd() * 7)
                }
                var c = Climb(date: t, scale: "v", grade: g, outcome: o, attempts: att)
                c.place = place; c.outdoor = outdoor
                c.tape = outdoor ? nil : Int(rnd() * 10)
                if rnd() < 0.55 { c.tags = [styles[Int(rnd() * Double(styles.count))], styles[Int(rnd() * 8)]].reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } } }
                if hard >= 0 && rnd() < 0.5 { c.name = names[Int(rnd() * Double(names.count))] }
                climbs.append(c)
                t = t.addingTimeInterval(TimeInterval(6 + Int(rnd() * 12)) * 60)
            }
            n += 1
            day += 3 + Int(rnd() * 2)
        }
        // The month's best send: a V6 flash-close on the cave, with a photo.
        let best = today.addingTimeInterval(-4 * 86400 + 19.2 * 3600)
        var top = Climb(date: best, scale: "v", grade: 7, outcome: .send, attempts: 5)
        top.name = "Purple cave traverse"; top.place = "Crux Yard"; top.tape = 6; top.tags = ["Overhang", "Heel hook", "Compression"]
        top.note = "Start matched on the purple jug. Left heel on the volume, drop knee, then slap right to the sloper. Don't cut feet before the pinch."
        top.photo = "demo-wall"
        climbs.append(top)
        s.db.climbs = climbs.sorted { $0.date < $1.date }
        s.db.places = ["Crux Yard", "Sandbag Boulders", "Joe's Valley"]
        s.db.scale = "v"
        s.db.custom = [Scale(id: "crux", name: "Crux Yard circuits", grades: ["Green", "Blue", "Yellow", "Orange", "Red", "Pink", "Purple", "Black"], custom: true)]
        if let last = s.sessions(all: true).first { s.db.notes[last.id] = "Skin was thin but felt strong on crimps. Finally stuck the heel on the purple." }
    }

    static func draft(_ s: Store) -> Climb {
        var c = Climb(date: Date(), scale: "v", grade: 6, outcome: .send, attempts: 4)
        c.place = "Crux Yard"; c.tape = 1; c.tags = ["Crimpy", "Vertical"]
        return c
    }

    // MARK: drawn photo

    static func photo(_ name: String) -> UIImage? {
        let r = ImageRenderer(content: WallPhoto().frame(width: 600, height: 800))
        r.scale = 2
        return r.uiImage
    }
}

/// A steep gym wall with a purple problem taped up it, drawn rather than shot.
private struct WallPhoto: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x4B5563), Color(hex: 0x2F3640)], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                // Panel seams.
                for i in 1..<4 {
                    var p = Path(); p.move(to: CGPoint(x: size.width * CGFloat(i) / 4, y: 0)); p.addLine(to: CGPoint(x: size.width * CGFloat(i) / 4 - 60, y: size.height))
                    ctx.stroke(p, with: .color(.black.opacity(0.25)), lineWidth: 2)
                }
                // Texture.
                var seed: UInt64 = 9
                func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
                for _ in 0..<2500 {
                    let x = rnd() * size.width, y = rnd() * size.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(.white.opacity(0.06)))
                }
                // Chalk smudges.
                for _ in 0..<14 {
                    let x = rnd() * size.width, y = rnd() * size.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 60, height: 40)), with: .color(.white.opacity(0.07)))
                }
            }
            // Other problems' holds.
            ForEach(0..<16, id: \.self) { i in
                let c = Ply.circuit[(i * 3) % Ply.circuit.count]
                HoldShape(seed: i * 13 + 2).fill(c)
                    .frame(width: 40 + CGFloat((i * 17) % 30), height: 34 + CGFloat((i * 11) % 24))
                    .position(x: CGFloat((i * 137) % 560) + 20, y: CGFloat((i * 211) % 760) + 20)
                    .opacity(0.8)
            }
            // The purple problem, with its tape.
            ForEach(0..<7, id: \.self) { i in
                let pts: [CGPoint] = [CGPoint(x: 120, y: 700), CGPoint(x: 210, y: 590), CGPoint(x: 170, y: 470), CGPoint(x: 300, y: 390), CGPoint(x: 260, y: 270), CGPoint(x: 400, y: 190), CGPoint(x: 470, y: 90)]
                ZStack {
                    HoldShape(seed: i * 7 + 60).fill(Color(hex: 0x7F4FD6))
                        .overlay(HoldShape(seed: i * 7 + 60).fill(LinearGradient(colors: [.white.opacity(0.35), .clear, .black.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .frame(width: i == 6 ? 110 : 76, height: i == 6 ? 80 : 62)
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 4, y: 8)
                    TornTape().fill(Color(hex: 0x7F4FD6)).frame(width: 36, height: 12).offset(x: -46, y: 26).rotationEffect(.degrees(-20))
                        .overlay(TornTape().stroke(.white.opacity(0.3)).frame(width: 36, height: 12).offset(x: -46, y: 26).rotationEffect(.degrees(-20)))
                }
                .position(pts[i])
            }
            Text("V6").font(.system(size: 40, weight: .black).width(.expanded)).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 4).background(TornTape().fill(Color(hex: 0x7F4FD6))).rotationEffect(.degrees(-6))
                .position(x: 110, y: 760)
            RadialGradient(colors: [.clear, .black.opacity(0.45)], center: .center, startRadius: 220, endRadius: 560)
        }
    }
}
