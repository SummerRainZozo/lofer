import SwiftUI

/// Profile: a few answers Lofer uses to tune programmes and keep sessions safe.
struct ProfileView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let p = app.memory.profile
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.name.isEmpty ? "Your profile" : "Hi, \(p.name)").font(LoferFont.ui(32, .light)).foregroundStyle(Color.loferCream)
                    Text("Lofer uses these answers to pick the programme and pressure for each session. Change them any time.").font(LoferFont.ui(14)).foregroundStyle(Color.loferMuted)
                }
                typicalSession
                group("About you") {
                    TextField("First name", text: binding(\.name)).font(LoferFont.body).padding(10).background(RoundedRectangle(cornerRadius: 12).stroke(Color.loferLine2))
                    one("Age range", ["18–24", "25–34", "35–44", "45–54", "55–64", "65+"], \.age)
                    one("Sex", ["Female", "Male", "Prefer not to say"], \.sex)
                }
                group("How you move") {
                    many("What exercise do you do?", ["Running", "Cycling", "Gym & weights", "Tennis & racket sports", "Football", "Swimming", "Yoga & Pilates", "Climbing", "Golf", "Hiking", "None right now"], \.sports)
                    one("How often?", ["Rarely", "1–2 times a week", "3–4 times a week", "5+ times a week"], \.frequency)
                    one("Most of your day is spent…", ["Sitting at a desk", "Standing", "On the move", "A mix"], \.posture)
                }
                group("Comfort") {
                    oneRequired("Pressure you usually like", ["Gentle", "Moderate", "Firm"], \.pressure)
                    oneRequired("Session length", ["10 min", "15 min", "20 min"], \.length)
                    Toggle("Warmth during sessions", isOn: binding(\.heat)).tint(Color(hex: 0xD9AE92))
                    many("What do you want from Lofer?", ["Relieve pain", "Recover after training", "Relax and de-stress", "Move more freely"], \.goals)
                }
                group("Safety check") {
                    Toggle("Pregnant", isOn: binding(\.pregnant)); Toggle("Pacemaker or implanted device", isOn: binding(\.implant))
                    Toggle("Injury or surgery in the last 6 weeks", isOn: binding(\.recentInjury)); Toggle("Blood clotting condition or blood thinners", isOn: binding(\.clotting))
                    Text("If any of these apply, Lofer keeps pressure gentle and suggests checking with a clinician first.").font(LoferFont.caption).foregroundStyle(Color.loferFaint)
                }
                .tint(Color(hex: 0xD9AE92))
                group("Device") {
                    HStack { Text("Lofer wearable"); Spacer(); Text("Simulated").foregroundStyle(Color.loferMuted) }
                    Text("No hardware yet. Sessions run on a simulated device and are recorded the same way a real one will be.").font(LoferFont.caption).foregroundStyle(Color.loferFaint)
                }
                if !app.memory.routines.isEmpty {
                    group("Saved routines") {
                        ForEach(app.memory.routines.sorted(by: { $0.key < $1.key }), id: \.key) { k, r in
                            HStack { VStack(alignment: .leading) { Text(r.name); Text(r.steps.map { "\($0.modality.short) \($0.minutes) min" }.joined(separator: " → ")).font(LoferFont.caption).foregroundStyle(Color.loferMuted) }
                                Spacer(); Button("Remove") { app.memory.removeRoutine(k) }.foregroundStyle(Color(hex: 0xE7A58F)) }
                        }
                    }
                }
                group("Your data") {
                    Button("Restore sample episodes") { app.memory.restoreSamples() }.foregroundStyle(Color.loferPeach)
                    Button("Clear Body Memory") { app.memory.clear() }.foregroundStyle(Color(hex: 0xE7A58F))
                }
                group("Design (temporary)") { Button("Typography candidates") { app.path.append(.typography) }.foregroundStyle(Color.loferPeach) }
            }
            .font(LoferFont.ui(14.5)).foregroundStyle(Color.loferCream)
            .padding(18)
        }
        .background(LoferBackground())
    }

    private var typicalSession: some View {
        let p = app.memory.profile
        let s = SymptomSnapshot(areaId: nil, type: "tightness", triggers: [], flags: [])
        let tri = SafetyValidator.triage(s, profile: p)
        let sug = TreatmentEngine.suggest(s, tri, profile: p, history: [], routine: nil)
        let v = SafetyValidator.validate(sug.options[1], tri)
        return VStack(alignment: .leading, spacing: 6) {
            Text("A typical session for you").eyebrowStyle()
            Text("\(v.plan.name) · \(v.plan.minutes) min · \(v.plan.levelText)").font(LoferFont.ui(16, .medium))
            Text(v.plan.sequenceText + (tri.level == .caution ? ". Kept gentle because of your safety answers." : ".")).font(LoferFont.ui(13)).foregroundStyle(Color.loferMuted)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(RadialGradient(colors: [Color.loferPeach.opacity(0.16), Color(hex: 0x282321).opacity(0.5)], center: .topLeading, startRadius: 0, endRadius: 300)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.loferPeach.opacity(0.22)))
    }

    // MARK: small helpers bound to the stored profile
    private func binding<T>(_ kp: WritableKeyPath<UserProfile, T>) -> Binding<T> {
        Binding(get: { app.memory.profile[keyPath: kp] }, set: { v in app.memory.updateProfile { $0[keyPath: kp] = v } })
    }
    private func group<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrowStyle()
            VStack(alignment: .leading, spacing: 12) { c() }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: 0x282321).opacity(0.55))).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.loferLine))
        }
    }
    private func one(_ label: String, _ opts: [String], _ kp: WritableKeyPath<UserProfile, String?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
            FlowLayout { ForEach(opts, id: \.self) { o in Chip(title: o, selected: app.memory.profile[keyPath: kp] == o) { app.memory.updateProfile { $0[keyPath: kp] = $0[keyPath: kp] == o ? nil : o } } } }
        }
    }
    private func oneRequired(_ label: String, _ opts: [String], _ kp: WritableKeyPath<UserProfile, String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
            FlowLayout { ForEach(opts, id: \.self) { o in Chip(title: o, selected: app.memory.profile[keyPath: kp] == o) { app.memory.updateProfile { $0[keyPath: kp] = o } } } }
        }
    }
    private func many(_ label: String, _ opts: [String], _ kp: WritableKeyPath<UserProfile, [String]>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
            FlowLayout { ForEach(opts, id: \.self) { o in Chip(title: o, selected: app.memory.profile[keyPath: kp].contains(o)) {
                app.memory.updateProfile { p in
                    if p[keyPath: kp].contains(o) { p[keyPath: kp].removeAll { $0 == o } } else { p[keyPath: kp].append(o) }
                    if o == "None right now", p[keyPath: kp].contains(o) { p[keyPath: kp] = [o] } else if o != "None right now" { p[keyPath: kp].removeAll { $0 == "None right now" } }
                } } } }
        }
    }
}
