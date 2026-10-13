import Foundation
import Observation

@MainActor
@Observable
final class ThreadListModel {
  enum State: Equatable {
    case loading
    case loaded([ThreadSummary])
    case failed(HermesClientError)
  }

  private(set) var state = State.loading
  /// Why the list on screen could not be brought up to date; it shows the
  /// chats saved last time meanwhile.
  private(set) var refreshFailure: HermesClientError?
  private(set) var activeProfile: String?
  private(set) var fetchedAt: Date?
  private(set) var showingSaved = false
  private var seen: ThreadSeenMarkers
  let client: HermesClient

  private let session: WatchSessionState
  private var cleanupId: UUID?

  init(client: HermesClient, session: WatchSessionState? = nil) {
    self.client = client
    seen = client.glanceCache?.seenMarkers() ?? ThreadSeenMarkers()
    let session = session ?? client.sessionState ?? WatchSessionState()
    self.session = session
    cleanupId = session.register { [weak self] in
      self?.state = .failed(session.invalidationReason)
      self?.refreshFailure = nil
      self?.activeProfile = nil
      self?.fetchedAt = nil
      self?.showingSaved = false
      self?.seen = ThreadSeenMarkers()
    }
  }

  /// Shows the chats saved last time, if there are any, until the phone
  /// answers.
  func load() async {
    let generation = session.generation
    if state == .loading, let saved = client.savedThreadListing() {
      state = .loaded(saved.threads)
      activeProfile = saved.activeProfile
      fetchedAt = saved.fetchedAt
      showingSaved = true
    }
    do {
      let listing = try await client.threadListing()
      guard generation == session.generation else { return }
      state = .loaded(listing.threads)
      activeProfile = listing.activeProfile
      fetchedAt = listing.fetchedAt
      showingSaved = false
      refreshFailure = nil
      seen.observeFresh(listing.threads)
      client.glanceCache?.save(seenMarkers: seen)
    } catch {
      guard generation == session.generation else { return }
      let failure = error as? HermesClientError ?? .failed
      if failure == .signedOut { session.invalidate() }
      if case .loaded = state, failure != .signedOut {
        refreshFailure = failure
        showingSaved = true
      } else {
        state = .failed(failure)
      }
    }
  }

  func listedUpdateTime(threadId: String) -> Date? {
    guard case .loaded(let threads) = state else { return nil }
    return threads.first { $0.id == threadId }?.updatedAt
  }

  func isUpdated(_ thread: ThreadSummary) -> Bool { seen.isUpdated(thread) }

  func markSeen(threadId: String, updatedAt: Date?) {
    guard session.owns(threadId) else { return }
    seen.markRead(threadId: threadId, updatedAt: updatedAt)
    client.glanceCache?.save(seenMarkers: seen)
  }
}
