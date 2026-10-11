import Foundation

extension SurfaceSnapshot {
  /// Made-up content for the widget gallery and placeholders, so the user's
  /// own chats never appear there.
  public static func sample(now: Date) -> SurfaceSnapshot {
    func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
    func chatLink(_ id: String) -> URL { URL(string: "hermes://chat?profile=default&id=\(id)")! }
    let titles = [
      ("Plan the trip", "Booked the flights and the first hotel."),
      ("Weekly review", "Here is what moved this week."),
      ("Draft the announcement", "A first version is ready."),
      ("Fix the build", "The tests pass again."),
      ("Meal ideas", "Three dinners that take twenty minutes."),
      ("Reading list", "Five books to start with."),
    ]
    let chats = titles.enumerated().map { index, entry in
      RecentChat(
        profile: "default", id: "sample\(index)", title: entry.0, snippet: entry.1,
        updatedAt: ago(Double(index) * 25 + 4), url: chatLink("sample\(index)"))
    }
    return SurfaceSnapshot(
      updatedAt: now, signedIn: true, profile: "default", profiles: ["default"],
      recentChats: chats,
      pending: [
        PendingRequest(
          profile: "default", threadId: "sample0", threadTitle: "Plan the trip", kind: .approval,
          requestId: "sample-r0", createdAt: ago(20), url: chatLink("sample0")),
        PendingRequest(
          profile: "default", threadId: "sample2", threadTitle: "Draft the announcement",
          kind: .question, requestId: "sample-r1", createdAt: ago(8), url: chatLink("sample2")),
      ],
      kanban: KanbanSummary(blocked: 1, review: 2),
      schedules: ScheduleSummary(
        nextRunAt: now.addingTimeInterval(3 * 3600), nextJobName: "Daily digest",
        lastFailed: FailedJob(
          profile: "default", jobId: "sample-job", name: "Backup", at: ago(300),
          url: URL(string: "hermes://schedules?profile=default&job=sample-job")!)))
  }
}
