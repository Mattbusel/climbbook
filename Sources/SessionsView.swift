import SwiftUI

/// Every session, newest first: where, how many tops, the hardest one.
struct SessionsView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        let list = store.sessions(all: pro.unlocked)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sessions").font(.wide(30)).foregroundStyle(Ply.ink).padding(.top, 8)
                if list.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No sessions yet").font(.wide(20)).foregroundStyle(Ply.ink)
                        Text("Every climb you log on the same day at the same place becomes a session, with its own notes.").font(.text(13.5)).foregroundStyle(Ply.dim)
                    }
                    .panel(18, radius: 24)
                }
                ForEach(groupedByMonth(list), id: \.0) { month, sessions in
                    Tape(month, color: Ply.ink).padding(.top, 8)
                    ForEach(sessions) { s in
                        Button { router.sheet = .session(s.id) } label: { SessionCard(session: s) }.buttonStyle(Press())
                    }
                }
                if !pro.unlocked && store.hiddenSessions > 0 {
                    Button { pro.paywall = .history } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.system(size: 17, weight: .bold)).foregroundStyle(Ply.send)
                            Text("\(store.hiddenSessions) older \(store.hiddenSessions == 1 ? "session" : "sessions")").font(.wide(18)).foregroundStyle(Ply.ink)
                            Text("Kept safe. Climbbook Pro shows your whole history, back to your first climb.").font(.text(13)).foregroundStyle(Ply.dim).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(20)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Ply.send.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }
                    .buttonStyle(Press())
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }

    func groupedByMonth(_ list: [Session]) -> [(String, [Session])] {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        var out: [(String, [Session])] = []
        for s in list {
            let k = f.string(from: s.day)
            if out.last?.0 == k { out[out.count - 1].1.append(s) } else { out.append((k, [s])) }
        }
        return out
    }
}

/// A session: the date, the place, and the climbs as a little row of holds.
struct SessionCard: View {
    @Environment(Store.self) private var store
    let session: Session
    var body: some View {
        let tops = session.climbs.filter { $0.outcome.topped }
        let best = tops.max { $0.grade < $1.grade }
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text(dayNum).font(.wide(26)).foregroundStyle(Ply.ink)
                Text(weekday).font(.tag(9.5)).foregroundStyle(Ply.dim)
            }
            .frame(width: 48)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: session.climbs.first?.outdoor == true ? "mountain.2.fill" : "building.2.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Ply.dim)
                    Text(session.place.isEmpty ? "Session" : session.place).font(.text(16, .bold)).foregroundStyle(Ply.ink).lineLimit(1)
                    Spacer()
                    if let best { Text("Best \(store.label(best))").font(.tag(10.5)).foregroundStyle(.white).padding(.horizontal, 8).frame(height: 22).background(Capsule().fill(store.color(best).isLight ? Ply.ink : store.color(best))) }
                }
                HStack(spacing: -6) {
                    ForEach(Array(session.climbs.sorted { $0.grade > $1.grade }.prefix(9).enumerated()), id: \.element.id) { i, c in
                        Hold(label: store.label(c), color: store.color(c), size: 34, seed: c.grade * 3 + i)
                            .opacity(c.outcome.topped ? 1 : 0.4)
                            .zIndex(Double(9 - i))
                    }
                    if session.climbs.count > 9 { Text("+\(session.climbs.count - 9)").font(.tag(11)).foregroundStyle(Ply.dim).padding(.leading, 12) }
                }
                Text("\(tops.count) \(tops.count == 1 ? "top" : "tops") · \(session.climbs.filter { $0.outcome == .flash }.count) flashed · \(session.climbs.reduce(0) { $0 + $1.attempts }) goes")
                    .font(.text(12)).foregroundStyle(Ply.dim)
                if !store.note(session).isEmpty {
                    Text("“\(store.note(session))”").font(.text(12.5).italic()).foregroundStyle(Ply.ink2).lineLimit(2)
                }
            }
        }
        .panel(14, radius: 22)
    }
    var dayNum: String { let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: session.day) }
    var weekday: String { let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: session.day).uppercased() }
}

/// One session: every climb in order, the tallies, and the session's notes.
struct SessionDetail: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let id: String
    @State private var note = ""

    var body: some View {
        if let s = store.session(id) {
            let tops = s.climbs.filter { $0.outcome.topped }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Tape(Fmt.day(s.day), color: Ply.project)
                            Text(s.place.isEmpty ? "Session" : s.place).font(.wide(26)).foregroundStyle(Ply.ink).padding(.top, 4)
                        }
                        Spacer()
                        CloseKnob { dismiss() }
                    }
                    .padding(.top, 24)
                    HStack(spacing: 10) {
                        big("\(tops.count)", "tops")
                        big("\(s.climbs.filter { $0.outcome == .flash }.count)", "flashes")
                        big("\(s.climbs.reduce(0) { $0 + $1.attempts })", "goes")
                        big(tops.max { $0.grade < $1.grade }.map { store.label($0) } ?? "–", "hardest")
                    }
                    // The session as a wall: holds placed by grade, left to right in the order climbed.
                    SessionWall(session: s).frame(height: 190).panel(10, radius: 24)
                    VStack(alignment: .leading, spacing: 10) {
                        Tape("Session notes")
                        TextField("", text: $note, prompt: Text("Skin was thin, felt strong on crimps…").foregroundColor(Ply.dim), axis: .vertical)
                            .lineLimit(2...6).font(.text(15)).foregroundStyle(Ply.ink)
                            .padding(14).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ply.panel))
                            .onChange(of: note) { _, t in store.setNote(s, t) }
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(s.climbs.enumerated()), id: \.element.id) { i, c in
                            if i > 0 { Divider().overlay(Ply.line).padding(.leading, 70) }
                            ClimbRow(climb: c)
                        }
                    }
                    .panel(6, radius: 22)
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
            .onAppear { note = store.note(s) }
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    func big(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.wide(22)).foregroundStyle(Ply.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(l.uppercased()).font(.tag(8.5)).foregroundStyle(Ply.dim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ply.panel))
    }
}

/// A mini wall: each climb is a hold, higher for harder, in the order you climbed them.
struct SessionWall: View {
    @Environment(Store.self) private var store
    let session: Session
    var body: some View {
        let cs = session.climbs
        let grades = cs.map(\.grade)
        let lo = (grades.min() ?? 0), hi = max((grades.max() ?? 1), lo + 1)
        GeometryReader { g in
            ZStack {
                Plywood().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                ForEach(Array(cs.enumerated()), id: \.element.id) { i, c in
                    let x = 24 + (cs.count > 1 ? CGFloat(i) / CGFloat(cs.count - 1) : 0.5) * (g.size.width - 48)
                    let y = 26 + (1 - CGFloat(c.grade - lo) / CGFloat(hi - lo)) * (g.size.height - 52)
                    Hold(label: store.label(c), color: store.color(c), size: 40, seed: c.grade * 11 + i)
                        .opacity(c.outcome.topped ? 1 : 0.45)
                        .overlay(alignment: .topTrailing) {
                            if c.outcome == .flash { Image(systemName: "bolt.fill").font(.system(size: 9, weight: .black)).foregroundStyle(Ply.ink).padding(3).background(Circle().fill(Ply.flash)).offset(x: 4, y: -2) }
                        }
                        .position(x: x, y: y)
                }
            }
        }
    }
}

struct ClimbRow: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    let climb: Climb
    var body: some View {
        Button { router.sheet = .climb(climb.id) } label: {
            HStack(spacing: 14) {
                Hold(label: store.label(climb), color: store.color(climb), size: 48, seed: climb.grade * 7 + 2)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(climb.name.isEmpty ? (climb.tape.map { Ply.tape[$0 % Ply.tape.count].0 + " " + store.label(climb) } ?? store.label(climb)) : climb.name)
                            .font(.text(15.5, .bold)).foregroundStyle(Ply.ink).lineLimit(1)
                        if climb.photo != nil { Image(systemName: "photo").font(.system(size: 11, weight: .bold)).foregroundStyle(Ply.dim) }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: climb.outcome.icon).font(.system(size: 10, weight: .black)).foregroundStyle(climb.outcome.color)
                        Text(climb.outcome.title).font(.text(12.5, .bold)).foregroundStyle(climb.outcome == .flash ? Ply.ink2 : climb.outcome.color)
                        Text("· \(climb.attempts) \(climb.attempts == 1 ? "go" : "goes")").font(.text(12.5)).foregroundStyle(Ply.dim)
                        if !climb.tags.isEmpty { Text("· \(climb.tags.prefix(2).joined(separator: ", "))").font(.text(12.5)).foregroundStyle(Ply.dim).lineLimit(1) }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One climb: the photo, the hold, how it went and the beta.
struct ClimbDetail: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let id: UUID

    var body: some View {
        if let c = store.climb(id) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .topTrailing) {
                        if let img = store.image(c.photo) {
                            Image(uiImage: img).resizable().scaledToFill().frame(height: 380).frame(maxWidth: .infinity).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                .overlay(alignment: .bottomLeading) {
                                    Hold(label: store.label(c), color: store.color(c), size: 96, seed: c.grade * 7 + 1).padding(16)
                                }
                        } else {
                            ZStack {
                                Plywood().clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                Hold(label: store.label(c), color: store.color(c), size: 150, seed: c.grade * 7 + 1)
                            }
                            .frame(height: 240)
                        }
                        CloseKnob { dismiss() }.padding(14)
                    }
                    .padding(.top, 18)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(c.name.isEmpty ? "\(store.label(c)) \(c.tape.map { Ply.tape[$0 % Ply.tape.count].0.lowercased() } ?? "")" : c.name).font(.wide(26)).foregroundStyle(Ply.ink)
                        Text("\(Fmt.day(c.date)) · \(Fmt.time(c.date))\(c.place.isEmpty ? "" : " · \(c.place)")").font(.text(13.5)).foregroundStyle(Ply.dim)
                    }
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: c.outcome.icon).font(.system(size: 14, weight: .black))
                            Text(c.outcome.title).font(.wide(15, .heavy))
                        }
                        .foregroundStyle(c.outcome == .flash ? Ply.ink : .white).padding(.horizontal, 14).frame(height: 40)
                        .background(Capsule().fill(c.outcome.color))
                        HStack(spacing: 10) {
                            Tally(count: min(c.attempts, 25), color: Ply.ink2, height: 20)
                            Text("\(c.attempts) \(c.attempts == 1 ? "go" : "goes")").font(.text(14, .bold)).foregroundStyle(Ply.ink2)
                        }
                        .padding(.horizontal, 14).frame(height: 40).background(Capsule().fill(Ply.panel))
                        Spacer(minLength: 0)
                    }
                    if !c.tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(c.tags, id: \.self) { t in
                                Text(t).font(.text(13, .bold)).foregroundStyle(Ply.ink2).padding(.horizontal, 12).frame(height: 30).background(Capsule().fill(Ply.wood2))
                            }
                        }
                    }
                    if !c.note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Tape("Beta")
                            Text(c.note).font(.text(15)).foregroundStyle(Ply.ink).fixedSize(horizontal: false, vertical: true)
                        }
                        .panel(16, radius: 20)
                    }
                    InkButton(title: "Edit", icon: "pencil") { router.sheet = .log(c) }
                    if c.outcome == .project {
                        SoftButton(title: "Sent it! Log the send", icon: "checkmark", tint: Ply.send) {
                            var n = Climb(date: Date(), scale: c.scale, grade: c.grade, outcome: .send, attempts: c.attempts + 1)
                            n.tape = c.tape; n.name = c.name; n.place = c.place; n.outdoor = c.outdoor; n.tags = c.tags
                            router.sheet = .log(n)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }
}
