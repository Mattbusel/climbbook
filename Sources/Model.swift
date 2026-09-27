import Foundation
import SwiftUI
import UIKit

enum Outcome: String, Codable, CaseIterable, Identifiable {
    case flash, send, project, repeat_
    var id: String { rawValue }
    var title: String {
        switch self {
        case .flash: return "Flash"
        case .send: return "Send"
        case .project: return "Project"
        case .repeat_: return "Repeat"
        }
    }
    var detail: String {
        switch self {
        case .flash: return "Topped first go"
        case .send: return "Topped it"
        case .project: return "Not yet"
        case .repeat_: return "Sent before"
        }
    }
    var icon: String {
        switch self {
        case .flash: return "bolt.fill"
        case .send: return "checkmark"
        case .project: return "arrow.triangle.2.circlepath"
        case .repeat_: return "repeat"
        }
    }
    var color: Color {
        switch self {
        case .flash: return Ply.flash
        case .send: return Ply.send
        case .project: return Ply.project
        case .repeat_: return Ply.ok
        }
    }
    /// Counts toward progression.
    var topped: Bool { self != .project }
}

/// A grading system: an ordered list of grade names.
struct Scale: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var grades: [String]
    var custom: Bool = false

    static let v = Scale(id: "v", name: "V scale", grades: ["VB", "V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12", "V13", "V14", "V15", "V16", "V17"])
    static let font = Scale(id: "font", name: "Font", grades: ["3", "4", "4+", "5", "5+", "6A", "6A+", "6B", "6B+", "6C", "6C+", "7A", "7A+", "7B", "7B+", "7C", "7C+", "8A", "8A+", "8B", "8B+", "8C", "8C+", "9A"])
    static let builtIn = [v, font]

    func label(_ i: Int) -> String { grades.indices.contains(i) ? grades[i] : "?" }
    func color(_ i: Int) -> Color { Ply.grade(i, of: grades.count) }
}

struct Climb: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var scale: String
    var grade: Int
    var outcome: Outcome = .send
    var attempts: Int = 1
    var tape: Int? = nil
    var tags: [String] = []
    var name: String = ""
    var place: String = ""
    var outdoor: Bool = false
    var note: String = ""
    var photo: String? = nil
}

struct Session: Identifiable, Hashable {
    var id: String
    let day: Date
    let place: String
    let climbs: [Climb]
}

struct DB: Codable {
    var climbs: [Climb] = []
    var scale: String = "v"
    var custom: [Scale] = []
    var notes: [String: String] = [:]
    var places: [String] = []
}

@MainActor
@Observable
final class Store {
    var db: DB
    let demo: Bool
    @ObservationIgnored private let url = URL.documentsDirectory.appending(path: "climbbook.json")
    static let photos = URL.documentsDirectory.appending(path: "photos")
    @ObservationIgnored private var cache: [String: UIImage] = [:]
    /// Free history reaches back this far. Older climbs are kept, never deleted.
    static let freeDays = 60

    init(demo: Bool) {
        self.demo = demo
        if demo { db = DB(); Demo.fill(self) }
        else if let data = try? Data(contentsOf: url), let d = try? JSONDecoder().decode(DB.self, from: data) { db = d }
        else { db = DB() }
    }

    func save() {
        guard !demo else { return }
        if let data = try? JSONEncoder().encode(db) { try? data.write(to: url, options: .atomic) }
    }

    // MARK: scales

    var scales: [Scale] { Scale.builtIn + db.custom }
    var scale: Scale { scales.first(where: { $0.id == db.scale }) ?? .v }
    func scale(_ id: String) -> Scale { scales.first(where: { $0.id == id }) ?? .v }
    func label(_ c: Climb) -> String { scale(c.scale).label(c.grade) }
    func color(_ c: Climb) -> Color { scale(c.scale).color(c.grade) }

    // MARK: climbs

    func add(_ c: Climb) {
        db.climbs.append(c)
        db.climbs.sort { $0.date < $1.date }
        let p = c.place.trimmingCharacters(in: .whitespaces)
        if !p.isEmpty { db.places.removeAll { $0 == p }; db.places.insert(p, at: 0) }
        save()
    }
    func update(_ c: Climb) {
        if let i = db.climbs.firstIndex(where: { $0.id == c.id }) { db.climbs[i] = c; db.climbs.sort { $0.date < $1.date }; save() }
    }
    func remove(_ c: Climb) {
        if let p = c.photo { try? FileManager.default.removeItem(at: Store.photos.appending(path: p)) }
        db.climbs.removeAll { $0.id == c.id }; save()
    }
    func climb(_ id: UUID) -> Climb? { db.climbs.first(where: { $0.id == id }) }

    /// Climbs on the current scale, the only ones that can be compared.
    var onScale: [Climb] { db.climbs.filter { $0.scale == db.scale } }

    /// Climbs sessions are made of, newest first. Free shows the last 60 days.
    func sessions(all: Bool) -> [Session] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -Store.freeDays, to: Date()) ?? .distantPast
        let list = all ? db.climbs : db.climbs.filter { $0.date >= cutoff }
        let groups = Dictionary(grouping: list) { c in "\(cal.startOfDay(for: c.date).timeIntervalSince1970)|\(c.place)" }
        return groups.map { k, v in Session(id: k, day: cal.startOfDay(for: v[0].date), place: v[0].place, climbs: v.sorted { $0.date < $1.date }) }
            .sorted { $0.day == $1.day ? $0.place < $1.place : $0.day > $1.day }
    }
    var hiddenSessions: Int { sessions(all: true).count - sessions(all: false).count }
    func session(_ id: String) -> Session? { sessions(all: true).first(where: { $0.id == id }) }
    func note(_ s: Session) -> String { db.notes[s.id] ?? "" }
    func setNote(_ s: Session, _ t: String) { db.notes[s.id] = t.isEmpty ? nil : t; save() }

    // MARK: records

    /// The hardest topped climb in a date range, flashes winning ties, then fewer attempts.
    func best(from: Date, to: Date = .distantFuture) -> Climb? {
        onScale.filter { $0.outcome.topped && $0.date >= from && $0.date < to }
            .max { a, b in
                if a.grade != b.grade { return a.grade < b.grade }
                if (a.outcome == .flash) != (b.outcome == .flash) { return b.outcome == .flash }
                return a.attempts > b.attempts
            }
    }
    var bestThisMonth: Climb? { best(from: Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()) }
    var hardestEver: Climb? { best(from: .distantPast) }
    var hardestFlash: Climb? { onScale.filter { $0.outcome == .flash }.max { $0.grade < $1.grade } }
    var hardestProject: Climb? { onScale.filter { $0.outcome == .send }.max { $0.attempts == $1.attempts ? $0.grade < $1.grade : $0.attempts < $1.attempts } }

    /// The best grade topped each week, oldest first.
    struct Week: Identifiable { var id: Date { start }; let start: Date; let best: Int?; let sends: Int }
    func weeks(_ n: Int) -> [Week] {
        let cal = Calendar.current
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<n).reversed().map { k in
            let s = cal.date(byAdding: .weekOfYear, value: -k, to: thisWeek) ?? thisWeek
            let e = cal.date(byAdding: .weekOfYear, value: 1, to: s) ?? s
            let tops = onScale.filter { $0.outcome.topped && $0.date >= s && $0.date < e }
            return Week(start: s, best: tops.map(\.grade).max(), sends: tops.count)
        }
    }

    /// Sends per grade, for the pyramid.
    func pyramid(since: Date?) -> [(grade: Int, flash: Int, send: Int)] {
        let tops = onScale.filter { $0.outcome.topped && (since == nil || $0.date >= since!) }
        let grades = Set(tops.map(\.grade)).sorted()
        return grades.map { g in (g, tops.filter { $0.grade == g && $0.outcome == .flash }.count, tops.filter { $0.grade == g && $0.outcome != .flash }.count) }
    }

    var streakWeeks: Int {
        var n = 0
        for w in weeks(52).reversed() { if w.sends > 0 { n += 1 } else if n > 0 || w.start < Date().addingTimeInterval(-7 * 86400) { break } }
        return n
    }

    // MARK: photos

    func savePhoto(_ image: UIImage) -> String? {
        try? FileManager.default.createDirectory(at: Store.photos, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        let s = max(image.size.width, image.size.height), k = min(1, 1800 / s)
        let size = CGSize(width: image.size.width * k, height: image.size.height * k)
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: f).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = img.jpegData(compressionQuality: 0.82) else { return nil }
        do { try data.write(to: Store.photos.appending(path: name)); return name } catch { return nil }
    }
    func image(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if let c = cache[name] { return c }
        let img = name.hasPrefix("demo-") ? Demo.photo(name) : UIImage(contentsOfFile: Store.photos.appending(path: name).path)
        if let img { cache[name] = img }
        return img
    }

    // MARK: export

    func csv() -> URL {
        var rows = ["date,time,place,outdoor,scale,grade,outcome,attempts,tape,name,tags,note"]
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let tf = DateFormatter(); tf.dateFormat = "HH:mm"
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        for c in db.climbs {
            rows.append([df.string(from: c.date), tf.string(from: c.date), q(c.place), c.outdoor ? "yes" : "no", q(scale(c.scale).name), q(label(c)), c.outcome.title,
                         "\(c.attempts)", c.tape.map { Ply.tape[$0 % Ply.tape.count].0 } ?? "", q(c.name), q(c.tags.joined(separator: "; ")), q(c.note)].joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "Climbbook.csv")
        try? rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
