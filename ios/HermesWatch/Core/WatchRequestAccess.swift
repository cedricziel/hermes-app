import Foundation
import Observation

/// Request privacy changes do not change the conversation's recovery identity.
@MainActor
@Observable
final class WatchRequestAccess {
  static let shared = WatchRequestAccess()
  private(set) var allowed = false
  private(set) var epoch = 0
  private var initialized = false
  private var owner: String?
  private var ownerRevision: Int?
  private var unavailable = false
  private var cleanup: [UUID: () -> Void] = [:]

  func acceptOwner(_ contextId: String, revision: Int) {
    guard owner != contextId || ownerRevision != revision else { return }
    owner = contextId
    ownerRevision = revision
    epoch = 0
    initialized = false
    unavailable = false
    allowed = false
    for action in cleanup.values { action() }
  }

  func receive(_ payload: [String: Any]) {
    guard let state = payload["watchRequests"] as? [String: Any] else { return }
    if state["unavailable"] as? Bool == true {
      unavailable = true
      allowed = false
      for action in cleanup.values { action() }
      return
    }
    guard let contextId = state["contextId"] as? String, contextId == owner,
      let revision = state["revision"] as? Int, revision == ownerRevision,
      let next = state["epoch"] as? Int, next >= epoch,
      let allowed = state["allowed"] as? Bool else { return }
    guard !unavailable || !allowed || next > epoch else { return }
    guard !initialized || next > epoch || allowed == self.allowed else { return }
    unavailable = false
    initialized = true
    if next > epoch || !allowed {
      for action in cleanup.values { action() }
    }
    epoch = next
    self.allowed = allowed
  }

  func register(_ action: @escaping () -> Void) -> UUID {
    let id = UUID()
    cleanup[id] = action
    if !allowed { action() }
    return id
  }
  func unregister(_ id: UUID) { cleanup.removeValue(forKey: id) }
}
