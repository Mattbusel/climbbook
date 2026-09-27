import SwiftUI

/// Grading systems, gyms, export, and Pro.
struct GearView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Gear").font(.wide(30)).foregroundStyle(Ply.ink).padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Tape("Grading system", color: Ply.send)
                    ForEach(store.scales) { s in scaleRow(s) }
                    Button {
                        guard pro.allow(.grades) else { return }
                        router.sheet = .scale(Scale(id: UUID().uuidString, name: "", grades: ["Green", "Blue", "Yellow", "Orange", "Red", "Black"], custom: true))
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus").font(.system(size: 15, weight: .black))
                            Text("Your gym's own system").font(.text(15, .bold))
                            Spacer()
                            if !pro.unlocked { Text("PRO").font(.tag(9)).foregroundStyle(Ply.ink).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Ply.flash)) }
                        }
                        .foregroundStyle(Ply.ink2).padding(.horizontal, 16).frame(height: 54)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Ply.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }
                    .buttonStyle(Press())
                    Text("Progression, records and the pyramid use the system picked here. Climbs logged on another system are kept and shown with their own grades.")
                        .font(.text(12)).foregroundStyle(Ply.dim).fixedSize(horizontal: false, vertical: true)
                }

                if !store.db.places.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Tape("Places", color: Ply.project)
                        VStack(spacing: 0) {
                            ForEach(Array(store.db.places.enumerated()), id: \.element) { i, p in
                                if i > 0 { Divider().overlay(Ply.line) }
                                HStack {
                                    Text(p).font(.text(15, .semibold)).foregroundStyle(Ply.ink)
                                    Spacer()
                                    Text("\(store.db.climbs.filter { $0.place == p }.count) climbs").font(.text(12.5)).foregroundStyle(Ply.dim)
                                    Button { store.db.places.removeAll { $0 == p }; store.save() } label: {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(Ply.dim.opacity(0.6))
                                    }
                                    .buttonStyle(.plain).accessibilityLabel("Forget \(p)")
                                }
                                .padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Ply.panel))
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Tape("Your data", color: Ply.ok)
                    if pro.unlocked {
                        ShareLink(item: store.csv()) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .bold))
                                Text("Export every climb (CSV)").font(.text(15, .bold))
                                Spacer()
                                Text("\(store.db.climbs.count)").font(.text(13, .bold)).foregroundStyle(Ply.dim)
                            }
                            .foregroundStyle(Ply.ink).padding(.horizontal, 16).frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ply.panel))
                        }
                    } else {
                        Button { pro.paywall = .export } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .bold))
                                Text("Export every climb (CSV)").font(.text(15, .bold))
                                Spacer()
                                Text("PRO").font(.tag(9)).foregroundStyle(Ply.ink).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Ply.flash))
                            }
                            .foregroundStyle(Ply.ink).padding(.horizontal, 16).frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ply.panel))
                        }
                        .buttonStyle(Press())
                    }
                }

                ProCard()
                Text("Climbbook keeps everything on this phone. No account, no tracking, no ads.")
                    .font(.text(11.5)).foregroundStyle(Ply.dim)
            }
            .padding(.horizontal, 18).padding(.bottom, 130)
        }
    }

    func scaleRow(_ s: Scale) -> some View {
        let on = store.db.scale == s.id
        return Button {
            withAnimation(.spring(response: 0.35)) { store.db.scale = s.id; store.save() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 19, weight: .bold)).foregroundStyle(on ? Ply.send : Ply.dim.opacity(0.5))
                    Text(s.name.isEmpty ? "Custom" : s.name).font(.wide(16, .heavy)).foregroundStyle(Ply.ink)
                    Spacer()
                    if s.custom {
                        Button { router.sheet = .scale(s) } label: { Text("Edit").font(.text(13, .bold)).foregroundStyle(Ply.project) }.buttonStyle(.plain)
                    }
                    Text("\(s.grades.count) grades").font(.text(12)).foregroundStyle(Ply.dim)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: -4) {
                        ForEach(s.grades.indices, id: \.self) { i in
                            Hold(label: s.grades[i], color: s.color(i), size: 40, seed: i * 5 + s.grades.count)
                        }
                    }
                }
                .scrollClipDisabled()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Ply.panel))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(on ? Ply.send : Ply.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(Press())
        .sensoryFeedback(.selection, trigger: on)
    }
}

/// Build a gym's own system: circuit colours, numbered circuits, whatever it uses (Pro).
struct ScaleEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var scale: Scale
    @State private var newGrade = ""

    var body: some View {
        let exists = store.db.custom.contains(where: { $0.id == scale.id })
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(exists ? "Edit system" : "New grading system").font(.wide(22)).foregroundStyle(Ply.ink)
                    Spacer()
                    CloseKnob { dismiss() }
                }
                .padding(.top, 24)
                VStack(alignment: .leading, spacing: 8) {
                    Tape("Name")
                    TextField("", text: $scale.name, prompt: Text("Boulder Barn circuits").foregroundColor(Ply.dim))
                        .font(.text(17, .semibold)).foregroundStyle(Ply.ink).padding(.horizontal, 14).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ply.panel))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Tape("Grades, easiest first")
                    VStack(spacing: 0) {
                        ForEach(scale.grades.indices, id: \.self) { i in
                            HStack(spacing: 12) {
                                Hold(label: "", color: scale.color(i), size: 30, seed: i * 5)
                                TextField("", text: Binding(get: { scale.grades.indices.contains(i) ? scale.grades[i] : "" }, set: { if scale.grades.indices.contains(i) { scale.grades[i] = $0 } }))
                                    .font(.text(16, .bold)).foregroundStyle(Ply.ink)
                                Button { if i > 0 { scale.grades.swapAt(i, i - 1) } } label: { Image(systemName: "arrow.up").foregroundStyle(i > 0 ? Ply.ink2 : Ply.dim.opacity(0.3)) }.buttonStyle(.plain)
                                Button { if scale.grades.count > 2 { scale.grades.remove(at: i) } } label: { Image(systemName: "minus.circle.fill").foregroundStyle(Ply.send.opacity(0.8)) }.buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                            if i < scale.grades.count - 1 { Divider().overlay(Ply.line) }
                        }
                    }
                    .padding(.horizontal, 14).background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ply.panel))
                    HStack {
                        TextField("", text: $newGrade, prompt: Text("Add a grade").foregroundColor(Ply.dim)).font(.text(16, .semibold)).foregroundStyle(Ply.ink)
                            .onSubmit(add)
                        Button(action: add) { Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundStyle(Ply.ink) }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).frame(height: 50).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ply.panel))
                }
                InkButton(title: "Save", icon: "checkmark", color: Ply.send) {
                    if scale.name.trimmingCharacters(in: .whitespaces).isEmpty { scale.name = "My gym" }
                    scale.grades = scale.grades.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    guard scale.grades.count >= 2 else { return }
                    if let i = store.db.custom.firstIndex(where: { $0.id == scale.id }) { store.db.custom[i] = scale } else { store.db.custom.append(scale) }
                    store.db.scale = scale.id
                    store.save(); dismiss()
                }
                if exists && !store.db.climbs.contains(where: { $0.scale == scale.id }) {
                    SoftButton(title: "Delete system", icon: "trash", tint: Ply.send) {
                        store.db.custom.removeAll { $0.id == scale.id }
                        if store.db.scale == scale.id { store.db.scale = "v" }
                        store.save(); dismiss()
                    }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
    }

    func add() {
        let g = newGrade.trimmingCharacters(in: .whitespaces)
        guard !g.isEmpty else { return }
        withAnimation { scale.grades.append(g) }
        newGrade = ""
    }
}
