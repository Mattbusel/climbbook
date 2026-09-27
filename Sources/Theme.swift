import SwiftUI
import UIKit

/// Climbbook's look: a bouldering gym wall. Birch plywood with a T-nut grid, resin holds in
/// circuit colours for grades, chalk, and a charcoal ink for type.
enum Ply {
    static let wood = Color(hex: 0xEFE6D6)
    static let wood2 = Color(hex: 0xE6DAC3)
    static let grain = Color(hex: 0xD9C8A8)
    static let panel = Color(hex: 0xFBF7EF)
    static let ink = Color(hex: 0x1E1B18)
    static let ink2 = Color(hex: 0x4A433B)
    static let dim = Color(hex: 0x8A7F70)
    static let line = Color(hex: 0x1E1B18, alpha: 0.08)
    static let send = Color(hex: 0xE8433A)
    static let flash = Color(hex: 0xF2B51E)
    static let project = Color(hex: 0x2F7FE0)
    static let ok = Color(hex: 0x2E9E5F)
    static let tnut = Color(hex: 0x5B5146)

    /// Circuit colours, easiest to hardest, the way gyms tape them.
    static let circuit: [Color] = [Color(hex: 0x3FB16B), Color(hex: 0x2F7FE0), Color(hex: 0xF2C12E), Color(hex: 0xF08A24), Color(hex: 0xE8433A),
                                   Color(hex: 0xD9468F), Color(hex: 0x7F4FD6), Color(hex: 0x2A2622), Color(hex: 0x19A7A0), Color(hex: 0x8C5A2B)]
    static func grade(_ i: Int, of n: Int) -> Color {
        guard n > 1 else { return circuit[0] }
        let k = Int((Double(i) / Double(n - 1) * Double(circuit.count - 1)).rounded())
        return circuit[max(0, min(circuit.count - 1, k))]
    }
    /// Tape colours for the problem itself.
    static let tape: [(String, Color)] = [("Green", Color(hex: 0x3FB16B)), ("Blue", Color(hex: 0x2F7FE0)), ("Yellow", Color(hex: 0xF2C12E)), ("Orange", Color(hex: 0xF08A24)),
                                          ("Red", Color(hex: 0xE8433A)), ("Pink", Color(hex: 0xE86CA8)), ("Purple", Color(hex: 0x7F4FD6)), ("Black", Color(hex: 0x2A2622)),
                                          ("White", Color(hex: 0xF7F4EE)), ("Teal", Color(hex: 0x19A7A0))]
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
    var isLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b > 0.72
    }
}

extension Font {
    /// Expanded, heavy: route-setter tape lettering.
    static func wide(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font { .system(size: size, weight: weight).width(.expanded) }
    static func text(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight) }
    static func tag(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .heavy).width(.expanded) }
}

// MARK: - Wall

/// Plywood with faint grain and a grid of T-nuts, the holes holds bolt into.
struct Plywood: View {
    var bolts = true
    var body: some View {
        ZStack {
            Ply.wood
            Canvas { ctx, size in
                var seed: UInt64 = 0x51AB
                func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
                // Grain: long soft wavy lines.
                var y: CGFloat = 0
                while y < size.height {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    let amp = 3 + rnd() * 7, f = 0.004 + rnd() * 0.006, ph = rnd() * 6
                    var x: CGFloat = 0
                    while x <= size.width { p.addLine(to: CGPoint(x: x, y: y + CGFloat(sin(Double(x) * f + ph) * amp))); x += 12 }
                    ctx.stroke(p, with: .color(Ply.grain.opacity(0.18 + rnd() * 0.25)), lineWidth: 0.8 + rnd() * 1.4)
                    y += 9 + rnd() * 22
                }
                guard bolts else { return }
                let step: CGFloat = 44
                var row = 0
                var by: CGFloat = 22
                while by < size.height {
                    var bx: CGFloat = row % 2 == 0 ? 22 : 44
                    while bx < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: bx - 3.2, y: by - 3.2, width: 6.4, height: 6.4)), with: .color(Ply.tnut.opacity(0.22)))
                        ctx.fill(Path(ellipseIn: CGRect(x: bx - 1.6, y: by - 1.6, width: 3.2, height: 3.2)), with: .color(Ply.tnut.opacity(0.35)))
                        bx += step
                    }
                    by += step; row += 1
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// A resin hold: a smooth lumpy blob with a bolt in it. Same seed, same hold.
struct HoldShape: Shape {
    var seed: Int
    var lumps: Int = 7
    func path(in r: CGRect) -> Path {
        var s = UInt64(truncatingIfNeeded: seed &* 2654435761 &+ 97)
        func rnd() -> Double { s = s &* 6364136223846793005 &+ 1442695040888963407; return Double(s >> 33) / Double(1 << 31) }
        let n = lumps
        let c = CGPoint(x: r.midX, y: r.midY)
        let pts: [CGPoint] = (0..<n).map { i in
            let a = Double(i) / Double(n) * 2 * .pi + rnd() * 0.3
            let k = 0.78 + rnd() * 0.22
            return CGPoint(x: c.x + CGFloat(cos(a) * k) * r.width / 2, y: c.y + CGFloat(sin(a) * k) * r.height / 2)
        }
        var p = Path()
        for i in 0..<n {
            let p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n]
            if i == 0 { p.move(to: p1) }
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        p.closeSubpath()
        return p
    }
}

/// A hold with a grade written on it: the grade chip used everywhere.
struct Hold: View {
    let label: String
    let color: Color
    var size: CGFloat = 56
    var seed: Int = 0
    var body: some View {
        ZStack {
            HoldShape(seed: seed).fill(color)
                .overlay(HoldShape(seed: seed).fill(LinearGradient(colors: [.white.opacity(0.38), .clear, .black.opacity(0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(HoldShape(seed: seed).stroke(.black.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.22), radius: size * 0.08, x: size * 0.03, y: size * 0.07)
            // Bolt.
            Circle().fill(Color.black.opacity(0.28)).frame(width: size * 0.12, height: size * 0.12).offset(x: size * 0.2, y: -size * 0.2)
            Text(label).font(.wide(label.count > 3 ? size * 0.22 : size * 0.3)).foregroundStyle(color.isLight ? Ply.ink : .white)
                .minimumScaleFactor(0.5).lineLimit(1).padding(.horizontal, size * 0.12)
        }
        .frame(width: size, height: size * 0.9)
    }
}

// MARK: - Surfaces and controls

struct Panel: ViewModifier {
    var pad: CGFloat = 16
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content.padding(pad)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Ply.panel)
                    .shadow(color: Color(hex: 0x6B5433, alpha: 0.14), radius: 14, y: 6)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Ply.line))
    }
}
extension View {
    func panel(_ pad: CGFloat = 16, radius: CGFloat = 22) -> some View { modifier(Panel(pad: pad, radius: radius)) }
}

/// Route tape: a strip of coloured tape with a torn end, for section labels.
struct Tape: View {
    let text: String
    var color: Color = Ply.ink
    init(_ text: String, color: Color = Ply.ink) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased()).font(.tag(11)).tracking(1.4).foregroundStyle(color.isLight ? Ply.ink : .white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(TornTape().fill(color))
            .rotationEffect(.degrees(-1.2))
    }
}

struct TornTape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 4, y: r.minY))
        let teeth = 5
        for i in 0..<teeth {
            let y0 = r.minY + r.height * CGFloat(i) / CGFloat(teeth)
            p.addLine(to: CGPoint(x: r.maxX, y: y0 + r.height / CGFloat(teeth) / 2))
            p.addLine(to: CGPoint(x: r.maxX - 4, y: y0 + r.height / CGFloat(teeth)))
        }
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct InkButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Ply.ink
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .heavy)) }
                Text(title).font(.wide(16, .heavy))
            }
            .foregroundStyle(color.isLight ? Ply.ink : .white)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color).shadow(color: color.opacity(0.3), radius: 12, y: 6))
        }
        .buttonStyle(Press())
    }
}

struct SoftButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Ply.ink
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .bold)) }
                Text(title).font(.text(15, .bold))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Ply.wood2))
        }
        .buttonStyle(Press())
    }
}

struct CloseKnob: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(Ply.ink2)
                .frame(width: 36, height: 36).background(Circle().fill(Ply.wood2))
        }
        .buttonStyle(Press())
        .accessibilityLabel("Close")
    }
}

/// Chalk tally marks: four strokes and a slash.
struct Tally: View {
    let count: Int
    var color: Color = Ply.ink
    var height: CGFloat = 26
    var body: some View {
        Canvas { ctx, s in
            let groups = count / 5, rest = count % 5
            var x: CGFloat = 2
            let gw = height * 0.95
            func stroke(_ a: CGPoint, _ b: CGPoint) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: max(2, height * 0.1), lineCap: .round))
            }
            for g in 0..<(groups + (rest > 0 ? 1 : 0)) {
                let n = g < groups ? 5 : rest
                for i in 0..<min(n, 4) {
                    let xx = x + CGFloat(i) * gw / 4.5 + CGFloat((i * 7 + g) % 3) - 1
                    stroke(CGPoint(x: xx, y: 2 + CGFloat(i % 2)), CGPoint(x: xx + 1.5, y: s.height - 2))
                }
                if n == 5 { stroke(CGPoint(x: x - 3, y: s.height * 0.72), CGPoint(x: x + gw * 0.8, y: s.height * 0.28)) }
                x += gw + height * 0.45
            }
        }
        .frame(width: max(height, CGFloat(count / 5 + 1) * height * 1.45), height: height)
    }
}

enum Fmt {
    static func day(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = cal.isDate(d, equalTo: Date(), toGranularity: .year) ? "EEEE d MMM" : "d MMM yyyy"
        return f.string(from: d)
    }
    static func short(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "d MMM"; return f.string(from: d) }
    static func month(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: d) }
    static func time(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: d) }
}
