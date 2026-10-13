import Foundation

#if DEBUG
  /// Canned chats for the simulator, which has no phone to relay through.
  /// Set HERMES_WATCH_DEMO to `list`, or to `chat` to open a chat too
  /// (`SIMCTL_CHILD_HERMES_WATCH_DEMO=chat xcrun simctl launch …`).
  /// `HERMES_WATCH_COMPLICATION` seeds the complications' status the same way.
  struct DemoClient: HermesClient {
    private static var mode: String? { ProcessInfo.processInfo.environment["HERMES_WATCH_DEMO"] }
    static var enabled: Bool { mode != nil }
    static var opensChat: Bool { mode == "chat" || mode?.hasPrefix("recovery_") == true || mode?.hasPrefix("conversation_") == true }
    static var startupText: String? {
      ["conversation_failed", "conversation_approval", "conversation_question"].contains(mode ?? "") ? "Review the backup plan" : nil
    }
    private static let fixtureSession: WatchSessionState = {
      let session = WatchSessionState()
      session.acceptContext("demo-context", revision: 1)
      return session
    }()
    var sessionState: WatchSessionState? { Self.fixtureSession }
    private static let fixtureStore: FilePendingSendStore = {
      let store = FilePendingSendStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("hermes-watch-demo-\(UUID().uuidString)"), capacity: mode == "recovery_capacity" ? 0 : 100)
      if let mode, ["recovery_pending", "recovery_uncertain", "recovery_no_thread", "recovery_not_sent", "recovery_confirmation"].contains(mode) {
        let state: SendRecoveryState = mode == "recovery_pending" ? .pending : mode == "recovery_not_sent" ? .notSent : .uncertain
        try? store.save(PendingSendRecord(sendId: "demo-send", contextId: "demo-context", revision: 1, profile: "demo",
          threadId: mode == "recovery_no_thread" ? nil : threads[0].id, text: "Check the backup", localMessageId: "demo-local", createdAt: .now, recoveryState: state))
      }
      return store
    }()
    var recoveryStore: PendingSendStore { Self.fixtureStore }
    func prepareRecovery() async throws {
      if Self.mode == "recovery_unsupported" { throw HermesClientError.updateRequired }
      if Self.mode == "recovery_capacity" { throw HermesClientError.recoveryCapacity }
    }
    func forgetSend(sendId: String) async throws {}

    static let threads = [
      ThreadSummary(id: WatchThreadId(contextId: "demo-context", profile: "demo", sessionId: "d1").encode(), title: "Why is the nightly backup slow?", updatedAt: .now.addingTimeInterval(-600), pinned: true),
      ThreadSummary(id: WatchThreadId(contextId: "demo-context", profile: "demo", sessionId: "d2").encode(), title: "Groceries for the weekend", updatedAt: .now.addingTimeInterval(-7_200), pinned: false),
      ThreadSummary(id: WatchThreadId(contextId: "demo-context", profile: "demo", sessionId: "d3").encode(), title: "Draft a reply to the landlord about the heating", updatedAt: .now.addingTimeInterval(-90_000), pinned: false),
    ]

    /// Puts a status where the complications read it, as the phone would send
    /// it: `HERMES_WATCH_COMPLICATION` is `working`, `waiting`, `ready`,
    /// `failed` or `none`.
    static func seedComplication() {
      guard let state = ProcessInfo.processInfo.environment["HERMES_WATCH_COMPLICATION"] else { return }
      ComplicationUpdates.receive([
        "v": 1, "state": state, "updatedAt": Date().timeIntervalSince1970 - 30,
        "title": threads[0].title, "threadId": threads[0].id,
      ])
    }

    func threads() async throws -> [ThreadSummary] { Self.threads }

    func messages(threadId: String) async throws -> [ChatMessage] {
      if Self.mode == "conversation_old_payload" { return [] }
      if Self.mode == "conversation_long" {
        return [ChatMessage(id: "long-user", role: .user, content: "Explain the backup schedule", at: .distantPast),
          ChatMessage(id: "long-answer", role: .assistant,
            content: Array(repeating: "The backup starts at 02:00. Review the excluded folders before changing the schedule.", count: 20).joined(separator: "\n\n"), at: .distantPast)]
      }
      return [
        ChatMessage(id: "m1", role: .user, content: "Why is the nightly backup slow?", at: .now),
        ChatMessage(
          id: "m2",
          role: .assistant,
          content: """
            ## Findings
            The backup now copies **all of `~/Media`** again:
            - the exclude list was reset on Tuesday
            - 412 GB instead of 9 GB

            Add `~/Media/cache` back to the excludes and it should take *about 20 minutes*.
            """,
          at: .now,
          tools: ["terminal", "read_file"]
        ),
        ChatMessage(id: "m3", role: .user, content: "Do it", at: .now),
      ]
    }

    func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
      if Self.mode == "conversation_failed" {
        return SendResult(threadId: threadId ?? Self.threads[0].id, text: "Model unavailable", failed: true)
      }
      if Self.mode == "conversation_approval" || Self.mode == "conversation_question" {
        try await Task.sleep(for: .seconds(1))
        return SendResult(threadId: threadId ?? Self.threads[0].id, text: "", failed: false,
          waiting: Self.mode == "conversation_question" ? .question : .approval)
      }
      if Self.mode?.hasPrefix("recovery_") == true {
        let state: SendRecoveryState = Self.mode == "recovery_pending" ? .pending : Self.mode == "recovery_not_sent" ? .notSent : .uncertain
        return SendResult(threadId: Self.mode == "recovery_no_thread" ? nil : threadId, text: "", failed: false, recoveryState: state)
      }
      try await Task.sleep(for: .seconds(1))
      return SendResult(threadId: threadId ?? WatchThreadId(contextId: "demo-context", profile: "demo", sessionId: "d9").encode(), text: "Done. The next backup runs at **02:00**.", failed: false, tools: ["edit_file"])
    }

    func transcribe(audio: Data, mimeType: String) async throws -> String {
      if Self.mode == "voice_failed" { throw HermesClientError.phoneUnreachable }
      if Self.mode == "voice_empty" { return " " }
      if Self.mode == "voice_long" { return "Please review the backup schedule for each server and explain why the nightly backup copies all media again. Keep the existing backup and do not change any files." }
      return "Thanks"
    }
  }
#endif
