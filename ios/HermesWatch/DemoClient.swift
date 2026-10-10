import Foundation

#if DEBUG
  /// Canned chats for the simulator, which has no phone to relay through.
  /// Set HERMES_WATCH_DEMO to `list`, or to `chat` to open a chat too
  /// (`SIMCTL_CHILD_HERMES_WATCH_DEMO=chat xcrun simctl launch …`).
  struct DemoClient: HermesClient {
    private static var mode: String? { ProcessInfo.processInfo.environment["HERMES_WATCH_DEMO"] }
    static var enabled: Bool { mode != nil }
    static var opensChat: Bool { mode == "chat" }

    static let threads = [
      ThreadSummary(id: "d1", title: "Why is the nightly backup slow?", updatedAt: .now.addingTimeInterval(-600), pinned: true),
      ThreadSummary(id: "d2", title: "Groceries for the weekend", updatedAt: .now.addingTimeInterval(-7_200), pinned: false),
      ThreadSummary(id: "d3", title: "Draft a reply to the landlord about the heating", updatedAt: .now.addingTimeInterval(-90_000), pinned: false),
    ]

    func threads() async throws -> [ThreadSummary] { Self.threads }

    func messages(threadId: String) async throws -> [ChatMessage] {
      [
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
      try await Task.sleep(for: .seconds(1))
      return SendResult(threadId: threadId ?? "d9", text: "Done. The next backup runs at **02:00**.", failed: false, tools: ["edit_file"])
    }

    func transcribe(audio: Data, mimeType: String) async throws -> String { "Thanks" }
  }
#endif
