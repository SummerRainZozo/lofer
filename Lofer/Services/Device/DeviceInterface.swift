import Foundation

/// One reading from the wearable during a session.
struct DeviceReading {
    var t: Double              // seconds into the session
    var stepIndex: Int
    var modality: Modality
    var level: Int
    var pressure: Double       // kPa
    var skinTemp: Double       // °C
    var paused: Bool
    var done: Bool
}

/// DEVICE LAYER — anything that can run a session on the body.
///
///   DeviceInterface
///   ├── MockLoferDevice        ← now: simulated patches
///   └── PhysicalLoferDevice    ← later: Bluetooth driver for the real wearable
///
/// It only accepts SealedCommand / SealedLevelChange / SealedRetarget, which only
/// SafetyValidator can create. So the voice agent or the engine can never drive hardware directly.
protocol DeviceInterface: AnyObject {
    var name: String { get }
    var isSimulated: Bool { get }
    var isRunning: Bool { get }
    var activePatches: [String] { get }
    func start(_ command: SealedCommand)
    func setIntensity(_ change: SealedLevelChange)
    func retarget(_ change: SealedRetarget)
    func pause()
    func resume()
    /// Advance the device by `seconds` of session time and return the latest reading.
    func tick(seconds: Double) -> DeviceReading?
    /// Stop and return the session log (one entry every 10 s).
    func stop() -> (elapsed: Int, log: [Episode.LogEntry])?
}
