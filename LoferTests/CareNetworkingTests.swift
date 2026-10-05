import XCTest
@testable import Lofer

/// APICareIntelligenceService fails safely: every failure is a typed error (never a crash),
/// and the care flow falls back on-device. Uses a stubbed URLSession (no real network).
final class CareNetworkingTests: XCTestCase {
    private func service(_ handler: @escaping StubURLProtocol.Handler) -> APICareIntelligenceService {
        StubURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return APICareIntelligenceService(baseURL: URL(string: "http://lofer.test")!, timeout: 2, session: URLSession(configuration: config))
    }
    private func request() -> CareRequest {
        CareRequest(requestId: "req-1", sessionId: "s", turn: 1, latestUserInput: .init(kind: .utterance, text: "My right shoulder is tight."),
                    expectedField: "story", conversationHistory: [], currentAssessmentState: AssessmentState(), selectedBodyRegion: nil,
                    investigation: InvestigationState(), completedMovementChecks: [], relevantBodyMemory: [], currentCareFlowState: "listening")
    }
    private func expectError(_ s: APICareIntelligenceService, _ check: (CareIntelligenceError) -> Bool) async {
        do { _ = try await s.respond(to: request()); XCTFail("Expected an error") }
        catch let e as CareIntelligenceError { XCTAssertTrue(check(e), "\(e)") }
        catch { XCTFail("Untyped error: \(error)") }
    }

    func testRequestCarriesTheSessionContext() async throws {
        var sent: CareRequest?
        let s = service { req in
            sent = try? CareSchema.decoder().decode(CareRequest.self, from: req.bodyData)
            let body = try CareSchema.encoder().encode(LocalCareIntelligenceService.response(to: sent!))
            return (200, body)
        }
        let r = try await s.respond(to: request())
        XCTAssertEqual(sent?.latestUserInput.text, "My right shoulder is tight.")
        XCTAssertEqual(sent?.expectedField, "story")
        XCTAssertEqual(sent?.schemaVersion, CareSchema.version)
        XCTAssertEqual(r.requestId, "req-1")
    }
    func testServerErrorIsTyped() async { await expectError(service { _ in (500, Data()) }) { $0 == .badStatus(500) } }
    func testMalformedJSONIsTyped() async {
        await expectError(service { _ in (200, Data("{\"oops\":true}".utf8)) }) { if case .malformed = $0 { true } else { false } }
    }
    func testAnswerToAnotherRequestIsRejected() async {
        await expectError(service { req in
            var r = LocalCareIntelligenceService.response(to: try! CareSchema.decoder().decode(CareRequest.self, from: req.bodyData))
            r.requestId = "someone-else"
            return (200, try CareSchema.encoder().encode(r))
        }) { $0 == .mismatchedRequest }
    }
    func testOtherSchemaVersionIsRejected() async {
        await expectError(service { req in
            var r = LocalCareIntelligenceService.response(to: try! CareSchema.decoder().decode(CareRequest.self, from: req.bodyData))
            r.schemaVersion = 99
            return (200, try CareSchema.encoder().encode(r))
        }) { $0 == .schemaMismatch(99) }
    }
    func testUnknownActionIsMalformed() async {
        await expectError(service { req in
            let r = LocalCareIntelligenceService.response(to: try! CareSchema.decoder().decode(CareRequest.self, from: req.bodyData))
            var json = try JSONSerialization.jsonObject(with: CareSchema.encoder().encode(r)) as! [String: Any]
            json["recommendedNextAction"] = ["type": "setEMSIntensity", "level": 9]       // not an action Lofer has
            return (200, try JSONSerialization.data(withJSONObject: json))
        }) { if case .malformed = $0 { true } else { false } }
    }
    func testUnreachableIsTyped() async {
        await expectError(APICareIntelligenceService(baseURL: URL(string: "http://127.0.0.1:9")!, timeout: 2)) {
            if case .unavailable = $0 { true } else { false }
        }
    }
    func testActionsRoundTripInTheBackendShape() throws {
        let a = InvestigationAction.movementCheck(.init(movementId: "arm_raise", phase: .baseline, purpose: "p", targetObservation: "t"))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(a)) as! [String: Any]
        XCTAssertEqual(json["type"] as? String, "movementCheck")
        XCTAssertEqual(json["movementId"] as? String, "arm_raise")
        XCTAssertEqual(try JSONDecoder().decode(InvestigationAction.self, from: JSONEncoder().encode(a)), a)
    }
}

/// Answers URLSession requests in tests.
final class StubURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (Int, Data)
    nonisolated(unsafe) static var handler: Handler?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

extension URLRequest {
    /// URLSession moves httpBody into a stream for custom protocols; read it back.
    var bodyData: Data {
        if let b = httpBody { return b }
        guard let s = httpBodyStream else { return Data() }
        s.open(); defer { s.close() }
        var data = Data(); var buf = [UInt8](repeating: 0, count: 4096)
        while s.hasBytesAvailable { let n = s.read(&buf, maxLength: buf.count); if n <= 0 { break }; data.append(buf, count: n) }
        return data
    }
}
