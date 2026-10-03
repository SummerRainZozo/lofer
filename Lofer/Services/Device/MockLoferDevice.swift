import Foundation

/// A simulated Lofer wearable: four virtual patches, pressure and skin temperature.
/// Replace with PhysicalLoferDevice when hardware exists; nothing above this changes.
final class MockLoferDevice: DeviceInterface {
    let name = "Lofer wearable"
    let isSimulated = true
    private(set) var activePatches: [String] = []
    private var steps: [TreatmentStep] = []
    private var total: Double = 0
    private var t: Double = 0
    private var lastLog: Double = -10
    private var levelOverride: Int?
    private var skin = 32.4
    private var paused = false
    private var log: [Episode.LogEntry] = []
    var isRunning: Bool { !steps.isEmpty }

    func start(_ command: SealedCommand) {
        steps = command.steps
        total = Double(command.steps.reduce(0) { $0 + $1.minutes * 60 })
        t = 0; lastLog = -10; levelOverride = nil; skin = 32.4; paused = false; log = []
        activePatches = ["P1", "P2", "P3"]
    }
    func setIntensity(_ change: SealedLevelChange) { levelOverride = change.intensity }
    func retarget(_ change: SealedRetarget) { activePatches = ["P2", "P3", "P4"] }
    func pause() { paused = true }
    func resume() { paused = false }

    func tick(seconds: Double) -> DeviceReading? {
        guard isRunning else { return nil }
        if !paused { t = min(total, t + seconds) }
        var acc = 0.0, i = 0
        while i < steps.count { acc += Double(steps[i].minutes * 60); if t < acc { break }; i += 1 }
        i = min(i, steps.count - 1)
        let step = steps[i], level = levelOverride ?? step.intensity
        let wave = sin(2 * .pi * t / (step.modality == .vibration ? 4 : 12))
        let kpa: Double = step.modality == .heat ? Double(4 + level) : step.modality == .ems ? 6 : Double(8 + level * 8) * (1 + 0.2 * wave) + Double.random(in: -1...1)
        skin += ((step.modality == .heat ? 34 + Double(level) * 1.2 : 32.6) - skin) * min(1, seconds / 60)
        if t - lastLog >= 10 {
            log.append(.init(t: Int(t), modality: step.modality, level: level, pressure: (max(1, kpa) * 10).rounded() / 10, skinTemp: (skin * 10).rounded() / 10))
            lastLog = t
        }
        return DeviceReading(t: t, stepIndex: i, modality: step.modality, level: level, pressure: max(1, kpa), skinTemp: skin, paused: paused, done: t >= total)
    }

    func stop() -> (elapsed: Int, log: [Episode.LogEntry])? {
        guard isRunning else { return nil }
        let out = (Int(t), log)
        steps = []; activePatches = []
        return out
    }
}
