import Foundation

/// Result of the safety/triage gate.
struct TriageResult {
    enum Level: String { case ok, caution, stop }
    var level: Level
    var urgent: Bool
    /// Stopped only because information is missing (a "not sure" or skipped safety answer),
    /// not because of a reported warning sign. Lofer defers rather than clears.
    var deferred = false
    var reasons: [String]
    var guidance: String
    var maxIntensity: Int
    var maxMinutes: Int
    var noEMS: Bool
    var noHeat: Bool
}

/// A treatment command the device will accept. Its initializer is private to this file,
/// so ONLY SafetyValidator can create one. The voice agent and the care engine cannot
/// reach the hardware directly — that's enforced by the compiler, not by convention.
struct SealedCommand {
    let region: String
    let pair: String?
    let steps: [TreatmentStep]
    fileprivate init(region: String, pair: String?, steps: [TreatmentStep]) { self.region = region; self.pair = pair; self.steps = steps }
}
struct SealedLevelChange { let intensity: Int; let capped: Bool; fileprivate init(_ i: Int, _ c: Bool) { intensity = i; capped = c } }
struct SealedRetarget { let region: String; fileprivate init(_ r: String) { region = r } }

/// SAFETY LAYER — deterministic rules, no AI.
enum SafetyValidator {
    static let maxIntensity = 5, maxMinutes = 20, maxHeat = 3
    static let guidanceUrgent = "Please get urgent medical help now. If symptoms are severe or getting worse quickly, call your local emergency number."
    static let guidanceStop = "Please have it looked at by a GP or physiotherapist before using Lofer on this area."
    static let guidanceCaution = "I'll keep things gentle and short, and check in more often."
    static let guidanceDeferred = "I don't have enough information to recommend a session here. If you notice numbness, tingling, swelling or weakness, have it checked by a GP or physiotherapist."
    private static let noEMSArea = "neck_f|face|_neckside|chest|upper_abs|lower_abs|abdomen|headneck|backhead"
    private static let sensitive = "_kn_|_el_|_wr_|_ankle|_achilles|neck|face|backhead|_palm|_backhand|_thumb|_fingers|_heel|_sole|_foottop"

    static func triage(_ s: SymptomSnapshot, profile: UserProfile) -> TriageResult {
        var reasons: [String] = []; var level = TriageResult.Level.ok; var urgent = false
        var missingOnly = true   // every stop reason so far is missing information
        let area = s.areaId.map { BodyAtlas.shared.path(to: $0).joined(separator: " ") } ?? ""
        func bump(_ l: TriageResult.Level, _ why: String) {
            reasons.append(why)
            if l == .stop || (l == .caution && level == .ok) { level = l }
            if l == .stop { missingOnly = false }
        }
        // Unanswered warning-sign checks: never treated as a "no".
        for why in s.safetyUnresolved { reasons.append(why); level = .stop }
        // A pause stated after an earlier session is enforced, not just shown.
        if s.automaticCarePaused { bump(.stop, "Automatic sessions are paused for this area after an earlier session") }
        for f in s.flags {
            switch f.level { case .urgent: urgent = true; bump(.stop, f.label); case .stop: bump(.stop, f.label); case .caution: bump(.caution, f.label) }
        }
        if let sev = s.severity, sev >= 9 { bump(.stop, "Very severe pain (\(sev)/10)") }
        else if let sev = s.severity, sev >= 7 { bump(.caution, "Strong pain (\(sev)/10)") }
        if s.type == "sharp" { bump(.caution, "Described as sharp") }
        if s.type == "burning" { bump(.caution, "Described as burning") }
        if s.onset == "months ago" { bump(.caution, "Has lasted for months") }
        if s.atRest == "present" { bump(.caution, "There most of the time, even at rest") }
        if s.progression == "worsening" { bump(.caution, "Getting worse") }
        if let mv = s.movementBefore {
            if mv.feel == .cannot {
                if s.type == "sharp" || (s.severity ?? 0) >= 7 { bump(.stop, "Couldn’t do a simple movement comfortably, with strong or sharp pain") }
                else { bump(.caution, "Couldn’t do the movement check comfortably") }
            } else if mv.feel == .quite { bump(.caution, "Movement check was quite uncomfortable") }
        }
        if profile.clotting && area.has("_lleg|_calf|_thigh|_leg") { bump(.stop, "Leg discomfort with a blood clotting condition") }
        if profile.recentInjury { bump(.caution, "Injury or surgery in the last 6 weeks (from your profile)") }
        if profile.pregnant { bump(.caution, "Pregnancy (from your profile)") }
        if profile.implant { bump(.caution, "Implanted device (from your profile)") }
        if let id = s.areaId, id.has("neck_f|face") { bump(.caution, "Sensitive area") }
        let areaIds = area + " " + (s.areaId ?? "")
        let deferred = level == .stop && !urgent && missingOnly
        return TriageResult(
            level: level, urgent: urgent, deferred: deferred, reasons: reasons,
            guidance: urgent ? guidanceUrgent : deferred ? guidanceDeferred : level == .stop ? guidanceStop : level == .caution ? guidanceCaution : "",
            maxIntensity: level == .caution ? 2 : ((s.areaId ?? "").has(sensitive) ? 3 : maxIntensity),
            maxMinutes: level == .caution ? 10 : maxMinutes,
            noEMS: profile.implant || profile.pregnant || areaIds.has(noEMSArea) || level == .caution,
            noHeat: s.flags.contains { $0.label.has("Swelling|injury") } || (profile.pregnant && area.has("abdomen|lowerback|_lowback")))
    }

    struct Validation { var ok: Bool; var plan: TreatmentPlan; var notes: [String]; var command: SealedCommand? }

    /// Check a plan against the limits; return it adjusted, with plain-language notes, and sealed.
    static func validate(_ plan: TreatmentPlan, _ tri: TriageResult) -> Validation {
        guard tri.level != .stop else { return Validation(ok: false, plan: plan, notes: ["Treatment is not available for this situation."], command: nil) }
        var notes: [String] = []
        var steps = plan.steps
        if tri.noEMS && steps.contains(where: { $0.modality == .ems }) { steps.removeAll { $0.modality == .ems }; notes.append("Muscle stimulation left out for safety.") }
        if tri.noHeat && steps.contains(where: { $0.modality == .heat }) { steps.removeAll { $0.modality == .heat }; notes.append("Heat left out: not advised with swelling or a recent knock.") }
        var capped = false
        for i in steps.indices {
            let mx = steps[i].modality == .heat ? min(tri.maxIntensity, maxHeat) : tri.maxIntensity
            if steps[i].intensity > mx { steps[i].intensity = mx; capped = true }
            steps[i].intensity = max(1, steps[i].intensity); steps[i].minutes = max(1, steps[i].minutes)
        }
        if capped { notes.append("Intensity capped at level \(tri.maxIntensity).") }
        var total = steps.reduce(0) { $0 + $1.minutes }
        if total > tri.maxMinutes {
            let k = Double(tri.maxMinutes) / Double(total)
            for i in steps.indices { steps[i].minutes = max(1, Int((Double(steps[i].minutes) * k).rounded())) }
            total = steps.reduce(0) { $0 + $1.minutes }
            notes.append("Shortened to \(total) minutes.")
        }
        if steps.isEmpty { steps = [TreatmentStep(modality: .vibration, intensity: 1, minutes: 5)]; notes.append("Using a gentle vibration only.") }
        var out = plan; out.steps = steps
        return Validation(ok: true, plan: out, notes: notes, command: SealedCommand(region: plan.region, pair: plan.pair, steps: steps))
    }
    /// A change during treatment ("too strong") is checked the same way.
    static func validateLevel(_ level: Int, modality: Modality, _ tri: TriageResult) -> SealedLevelChange {
        let mx = modality == .heat ? min(tri.maxIntensity, maxHeat) : tri.maxIntensity
        let v = max(1, min(mx, level))
        return SealedLevelChange(v, v != level)
    }
    /// Moving the focus is allowed only within the same joint/segment.
    static func validateRetarget(from: String, to: String, _ tri: TriageResult) -> SealedRetarget? {
        guard tri.level != .stop, BodyAtlas.shared.group(of: from) == BodyAtlas.shared.group(of: to) else { return nil }
        return SealedRetarget(to)
    }
}
