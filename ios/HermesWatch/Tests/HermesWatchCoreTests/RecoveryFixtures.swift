import Foundation
@testable import HermesWatchCore

final class MemoryPendingSendStore: PendingSendStore {
  var values: [PendingSendRecord] = []
  var writeFailure = false
  private var blocked = Set<String>()
  func records(contextId: String, revision: Int) throws -> [PendingSendRecord] {
    values.filter { $0.contextId == contextId && $0.revision == revision && ![.completed, .discarded].contains($0.recoveryState) }
  }
  func save(_ record: PendingSendRecord) throws {
    if writeFailure { throw CocoaError(.fileWriteNoPermission) }
    guard !blocked.contains("\(record.contextId):\(record.revision)") else { throw PendingSendStoreError.invalidated }
    values.removeAll { $0.sendId == record.sendId }
    values.append(record)
  }
  func discard(sendId: String, contextId: String, revision: Int) throws {
    values.removeAll { $0.sendId == sendId && $0.contextId == contextId && $0.revision == revision }
  }
  func invalidate(contextId: String, revision: Int) throws {
    blocked.insert("\(contextId):\(revision)")
    values.removeAll { $0.contextId == contextId && $0.revision == revision }
  }
}

@MainActor
func recoveryFixtureSession() -> WatchSessionState {
  let session = WatchSessionState()
  session.acceptContext("test-context", revision: 1)
  return session
}
