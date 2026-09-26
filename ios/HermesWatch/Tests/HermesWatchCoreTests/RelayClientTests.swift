import XCTest

@testable import HermesWatchCore

final class FakeTransport: RelayTransport {
  var requests: [[String: Any]] = []
  var reply: Result<[String: Any], Error> = .success(["ok": true])

  func request(_ message: [String: Any]) async throws -> [String: Any] {
    requests.append(message)
    return try reply.get()
  }
}

final class RelayClientTests: XCTestCase {
  private var transport: FakeTransport!
  private var client: RelayClient!

  override func setUp() {
    transport = FakeTransport()
    client = RelayClient(transport: transport)
  }

  func testThreadsAreDecodedInOrder() async throws {
    transport.reply = .success([
      "ok": true,
      "threads": [
        ["id": "s1", "title": "Groceries", "updatedAt": 1_780_000_600, "pinned": true],
        ["id": "s2", "title": "Trip", "updatedAt": 1_780_000_100, "pinned": false],
      ],
    ])

    let threads = try await client.threads()

    XCTAssertEqual(transport.requests.first?["op"] as? String, "threads")
    XCTAssertEqual(threads.map(\.id), ["s1", "s2"])
    XCTAssertEqual(threads[0].title, "Groceries")
    XCTAssertTrue(threads[0].pinned)
    XCTAssertEqual(threads[0].updatedAt, Date(timeIntervalSince1970: 1_780_000_600))
  }

  func testThreadRowsMissingAnIdAreSkipped() async throws {
    transport.reply = .success([
      "ok": true,
      "threads": [["title": "No id"], ["id": "s1", "title": "Kept"]],
    ])

    let threads = try await client.threads()

    XCTAssertEqual(threads.map(\.id), ["s1"])
  }

  func testMessagesCarryRoleAndText() async throws {
    transport.reply = .success([
      "ok": true,
      "messages": [
        ["id": "s1-1", "role": "user", "content": "Hi", "at": 1_780_000_001],
        ["id": "s1-2", "role": "assistant", "content": "Hello", "at": 1_780_000_002],
      ],
    ])

    let messages = try await client.messages(threadId: "s1")

    XCTAssertEqual(transport.requests.first?["threadId"] as? String, "s1")
    XCTAssertEqual(messages.map(\.role), [.user, .assistant])
    XCTAssertEqual(messages.map(\.content), ["Hi", "Hello"])
  }

  func testSendToNewThreadOmitsThreadId() async throws {
    transport.reply = .success(["ok": true, "threadId": "new-1", "text": "Hi there", "failed": false])

    let result = try await client.send(threadId: nil, text: "Hello")

    let request = try XCTUnwrap(transport.requests.first)
    XCTAssertEqual(request["op"] as? String, "send")
    XCTAssertEqual(request["text"] as? String, "Hello")
    XCTAssertNil(request["threadId"])
    XCTAssertEqual(result, SendResult(threadId: "new-1", text: "Hi there", failed: false))
  }

  func testANewThreadReplyWithoutAThreadIdFails() async {
    transport.reply = .success(["ok": true, "text": "Hi there", "failed": false])

    do {
      _ = try await client.send(threadId: nil, text: "Hello")
      XCTFail("expected a throw")
    } catch {
      XCTAssertEqual(error as? HermesClientError, .failed)
    }
  }

  func testSendIntoAThreadPassesItsId() async throws {
    transport.reply = .success(["ok": true, "threadId": "s1", "text": "Done", "failed": true])

    let result = try await client.send(threadId: "s1", text: "More")

    XCTAssertEqual(transport.requests.first?["threadId"] as? String, "s1")
    XCTAssertTrue(result.failed)
  }

  func testPhoneErrorsMapToClientErrors() async {
    let cases: [(String, HermesClientError)] = [
      ("signed_out", .signedOut),
      ("unavailable", .unavailable),
      ("failed", .failed),
      ("something_new", .failed),
    ]
    for (code, expected) in cases {
      transport.reply = .success(["ok": false, "error": code])
      do {
        _ = try await client.threads()
        XCTFail("expected \(code) to throw")
      } catch {
        XCTAssertEqual(error as? HermesClientError, expected, code)
      }
    }
  }

  func testTransportErrorsPassThrough() async {
    transport.reply = .failure(HermesClientError.phoneUnreachable)

    do {
      _ = try await client.threads()
      XCTFail("expected a throw")
    } catch {
      XCTAssertEqual(error as? HermesClientError, .phoneUnreachable)
    }
  }

  func testMalformedReplyFails() async {
    transport.reply = .success(["ok": true])

    do {
      _ = try await client.threads()
      XCTFail("expected a throw")
    } catch {
      XCTAssertEqual(error as? HermesClientError, .failed)
    }
  }

  func testTranscribeSendsTheRecordingAndReturnsTheText() async throws {
    transport.reply = .success(["ok": true, "text": "Hello there"])

    let text = try await client.transcribe(audio: Data([1, 2]), mimeType: "audio/mp4")

    XCTAssertEqual(transport.requests.first?["op"] as? String, "transcribe")
    XCTAssertEqual(transport.requests.first?["audio"] as? Data, Data([1, 2]))
    XCTAssertEqual(transport.requests.first?["mimeType"] as? String, "audio/mp4")
    XCTAssertEqual(text, "Hello there")
  }
}
