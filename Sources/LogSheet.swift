import SwiftUI
import PhotosUI

/// Log a climb between attempts: grade, how it went, how many goes. Everything else is optional.
struct LogSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(Pro.self) private var pro
    @Environment(\.dismiss) private var dismiss
    @State var climb: Climb
    @State private var more = false
    @State private var logged = 0
    @State private var toast: String? = nil
    @State private var pick: PhotosPickerItem?
    @State private var camera = false

    static let tags = ["Crimpy", "Slopey", "Pinchy", "Jugs", "Slab", "Vertical", "Overhang", "Roof", "Dyno", "Compression", "Heel hook", "Toe hook", "Mantle", "Coordination", "Highball", "Traverse"]

    var exists: Bool { store.climb(climb.id) != nil }
    var scale: Scale { store.scale(climb.scale) }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text(exists ? "Edit climb" : "Log a climb").font(.wide(24)).foregroundStyle(Ply.ink)
                        Spacer()
                        CloseKnob { dismiss() }
                    }
                    .padding(.top, 24)
                    gradeWall
                    outcome
                    attempts
                    place
                    tapeRow
                    if more || exists { extras } else {
                        Button { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { more = true } } label: {
                            Label("Name, style, photo and notes", systemImage: "plus.circle").font(.text(14.5, .bold)).foregroundStyle(Ply.ink2)
                        }
                        .buttonStyle(.plain)
                    }
                    VStack(spacing: 10) {
                        InkButton(title: exists ? "Save" : "Log it", icon: "checkmark", color: Ply.send) { save(close: true) }
                        if !exists {
                            SoftButton(title: "Log it and start the next", icon: "arrow.right") { save(close: false) }
                        }
                        if exists {
                            SoftButton(title: "Delete climb", icon: "trash", tint: Ply.send) { store.remove(climb); dismiss() }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            if let toast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(toast).font(.text(14, .bold))
                }
                .foregroundStyle(.white).padding(.horizontal, 16).frame(height: 44)
                .background(Capsule().fill(Ply.ink).shadow(color: .black.opacity(0.25), radius: 12, y: 6))
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: logged)
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { img in if let img, let n = store.savePhoto(img) { climb.photo = n } }.ignoresSafeArea()
        }
        .onChange(of: pick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data), let n = store.savePhoto(img) { climb.photo = n }
                pick = nil
            }
        }
    }

    // MARK: grade

    /// Grades as a row of holds on the wall, the chosen one big and chalked.
    var gradeWall: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Tape("Grade", color: scale.color(climb.grade))
                Spacer()
                Text(scale.name).font(.text(12, .semibold)).foregroundStyle(Ply.dim)
            }
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(scale.grades.indices, id: \.self) { i in
                            let on = climb.grade == i
                            Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { climb.grade = i } } label: {
                                Hold(label: scale.label(i), color: scale.color(i), size: on ? 76 : 56, seed: i * 7 + 1)
                                    .rotationEffect(.degrees(on ? 0 : Double((i * 29) % 24) - 12))
                                    .opacity(on ? 1 : 0.85)
                                    .frame(width: 80, height: 80)
                            }
                            .buttonStyle(.plain)
                            .id(i)
                        }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 4)
                }
                .scrollClipDisabled()
                .onAppear { proxy.scrollTo(climb.grade, anchor: .center) }
            }
            .sensoryFeedback(.selection, trigger: climb.grade)
        }
    }

    // MARK: outcome

    var outcome: some View {
        VStack(alignment: .leading, spacing: 10) {
            Tape("How it went")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Outcome.allCases) { o in
                    let on = climb.outcome == o
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            climb.outcome = o
                            if o == .flash { climb.attempts = 1 }
                            if o != .flash && climb.attempts == 1 && o == .send { climb.attempts = 2 }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: o.icon).font(.system(size: 17, weight: .black))
                                .foregroundStyle(on ? (o == .flash ? Ply.ink : .white) : o.color)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(on ? Color.white.opacity(o == .flash ? 0.5 : 0.22) : o.color.opacity(0.14)))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(o.title).font(.wide(15, .heavy))
                                Text(o.detail).font(.text(11.5, .semibold)).opacity(0.75)
                            }
                            .foregroundStyle(on ? (o == .flash ? Ply.ink : .white) : Ply.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? o.color : Ply.panel))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? .clear : Ply.line))
                    }
                    .buttonStyle(Press())
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: climb.outcome)
        }
    }

    // MARK: attempts

    var attempts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Tape("Goes")
            HStack(spacing: 14) {
                Button { withAnimation(.spring(response: 0.3)) { climb.attempts = max(1, climb.attempts - 1) } } label: {
                    Image(systemName: "minus").font(.system(size: 18, weight: .black)).foregroundStyle(Ply.ink)
                        .frame(width: 52, height: 52).background(Circle().fill(Ply.wood2))
                }
                .buttonStyle(Press())
                VStack(spacing: 4) {
                    Text("\(climb.attempts)").font(.wide(34)).foregroundStyle(Ply.ink).contentTransition(.numericText())
                    Tally(count: min(climb.attempts, 30), color: Ply.ink2, height: 20)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring(response: 0.3)) { climb.attempts += 1; if climb.outcome == .flash && climb.attempts > 1 { climb.outcome = .send } } }
                Button { withAnimation(.spring(response: 0.3)) { climb.attempts += 1; if climb.outcome == .flash { climb.outcome = .send } } } label: {
                    Image(systemName: "plus").font(.system(size: 20, weight: .black)).foregroundStyle(.white)
                        .frame(width: 60, height: 60).background(Circle().fill(Ply.ink))
                }
                .buttonStyle(Press())
            }
            .panel(12, radius: 22)
            .sensoryFeedback(.impact(weight: .light), trigger: climb.attempts)
        }
    }

    // MARK: place

    var place: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Tape("Where")
                Spacer()
                HStack(spacing: 2) {
                    ForEach([false, true], id: \.self) { o in
                        Button { withAnimation { climb.outdoor = o } } label: {
                            Label(o ? "Outdoor" : "Gym", systemImage: o ? "mountain.2.fill" : "building.2.fill").font(.text(12.5, .bold))
                                .foregroundStyle(climb.outdoor == o ? .white : Ply.ink2).padding(.horizontal, 10).frame(height: 30)
                                .background(Capsule().fill(climb.outdoor == o ? Ply.ink : .clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3).background(Capsule().fill(Ply.wood2))
            }
            TextField("", text: $climb.place, prompt: Text(climb.outdoor ? "Crag or boulder field" : "Gym").foregroundColor(Ply.dim))
                .font(.text(17, .semibold)).foregroundStyle(Ply.ink)
                .padding(.horizontal, 14).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ply.panel))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Ply.line))
            if !store.db.places.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.db.places.prefix(8), id: \.self) { p in
                            Button { climb.place = p } label: {
                                Text(p).font(.text(13, .bold)).foregroundStyle(climb.place == p ? .white : Ply.ink2)
                                    .padding(.horizontal, 12).frame(height: 32).background(Capsule().fill(climb.place == p ? Ply.ink : Ply.wood2))
                            }
                            .buttonStyle(Press())
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    var tapeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Tape("Tape colour")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Ply.tape.indices, id: \.self) { i in
                        let on = climb.tape == i
                        Button { withAnimation(.spring(response: 0.3)) { climb.tape = on ? nil : i } } label: {
                            TornTape().fill(Ply.tape[i].1).frame(width: 44, height: 22)
                                .overlay(TornTape().stroke(.black.opacity(0.12)))
                                .rotationEffect(.degrees(on ? -8 : 0))
                                .scaleEffect(on ? 1.2 : 1)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Ply.tape[i].0)
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: extras

    var extras: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Tape("Name")
                TextField("", text: $climb.name, prompt: Text("The blue one on the cave").foregroundColor(Ply.dim))
                    .font(.text(17, .semibold)).foregroundStyle(Ply.ink)
                    .padding(.horizontal, 14).frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ply.panel))
            }
            VStack(alignment: .leading, spacing: 10) {
                Tape("Style")
                FlowLayout(spacing: 8) {
                    ForEach(LogSheet.tags, id: \.self) { t in
                        let on = climb.tags.contains(t)
                        Button { if on { climb.tags.removeAll { $0 == t } } else { climb.tags.append(t) } } label: {
                            Text(t).font(.text(13.5, .bold)).foregroundStyle(on ? .white : Ply.ink2)
                                .padding(.horizontal, 12).frame(height: 34)
                                .background(Capsule().fill(on ? Ply.project : Ply.wood2))
                        }
                        .buttonStyle(Press())
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Tape("Photo")
                    if !pro.unlocked { Text("PRO").font(.tag(9)).foregroundStyle(Ply.ink).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Ply.flash)) }
                }
                if let img = store.image(climb.photo) {
                    Image(uiImage: img).resizable().scaledToFill().frame(height: 220).frame(maxWidth: .infinity).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button { climb.photo = nil } label: {
                                Image(systemName: "trash").font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: 34, height: 34).background(Circle().fill(.black.opacity(0.5)))
                            }
                            .padding(10)
                        }
                }
                HStack(spacing: 10) {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        SoftButton(title: "Camera", icon: "camera.fill") { if pro.allow(.photos) { camera = true } }
                    }
                    if pro.unlocked {
                        PhotosPicker(selection: $pick, matching: .images) {
                            Label("Library", systemImage: "photo.on.rectangle").font(.text(15, .bold)).foregroundStyle(Ply.ink)
                                .frame(maxWidth: .infinity).frame(height: 46).background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Ply.wood2))
                        }
                    } else {
                        SoftButton(title: "Library", icon: "photo.on.rectangle") { pro.paywall = .photos }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Tape("Beta and notes")
                TextField("", text: $climb.note, prompt: Text("Left heel on the volume, then match the sloper…").foregroundColor(Ply.dim), axis: .vertical)
                    .lineLimit(3...8).font(.text(15)).foregroundStyle(Ply.ink)
                    .padding(14).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ply.panel))
            }
            DatePicker("When", selection: $climb.date, in: ...Date().addingTimeInterval(60)).font(.text(15, .bold)).foregroundStyle(Ply.ink).tint(Ply.send)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    func save(close: Bool) {
        var c = climb
        c.place = c.place.trimmingCharacters(in: .whitespaces)
        if exists { store.update(c) } else { store.add(c) }
        logged += 1
        if close { dismiss(); return }
        let label = "\(scale.label(c.grade)) \(c.outcome.title.lowercased()) logged"
        var next = Climb(date: Date(), scale: c.scale, grade: c.grade)
        next.place = c.place; next.outdoor = c.outdoor
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { climb = next; toast = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { toast = nil } }
    }
}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for s in subviews {
            let d = s.sizeThatFits(.unspecified)
            if x + d.width > w && x > 0 { x = 0; y += row + spacing; row = 0 }
            x += d.width + spacing; row = max(row, d.height)
        }
        return CGSize(width: w, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for s in subviews {
            let d = s.sizeThatFits(.unspecified)
            if x + d.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(d))
            x += d.width + spacing; row = max(row, d.height)
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.done(info[.originalImage] as? UIImage); parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.done(nil); parent.dismiss() }
    }
}
