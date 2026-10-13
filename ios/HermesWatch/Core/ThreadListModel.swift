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
  let client: HermesClient

  private let session: WatchSessionState
  private var cleanupId: UUID?

  init(client: HermesClient, session: WatchSessionState? = nil) {
    self.client = client
    let session = session ?? client.sessionState ?? WatchSessionState()
    self.session = session
    cleanupId = session.register { [weak self] in
      self?.state = .failed(.signedOut)
      self?.refreshFailure = nil
    }
  }

  /// Shows the chats saved last time, if there are any, until the phone
  /// answers.
  func load() async {
    let generation = session.generation
    guard session.usable else { state = .failed(.signedOut); return }
    if state == .loading, let saved = client.savedThreads() { state = .loaded(saved) }
    do {
      let threads = try await client.threads()
      guard generation == session.generation else { return }
      state = .loaded(threads)
      refreshFailure = nil
    } catch {
      guard generation == session.generation else { return }
      let failure = error as? HermesClientError ?? .failed
      if failure == .signedOut { session.invalidate() }
      if case .loaded = state, failure != .signedOut {
        refreshFailure = failure
      } else {
        state = .failed(failure)
      }
    }
  }
}
