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
  let cache: ChatCache

  init(client: HermesClient, cache: ChatCache = NoChatCache()) {
    self.client = client
    self.cache = cache
    if let saved = cache.threads() { state = .loaded(saved) }
  }

  func load() async {
    do {
      let threads = try await client.threads()
      state = .loaded(threads)
      refreshFailure = nil
      cache.save(threads: threads)
    } catch {
      let failure = error as? HermesClientError ?? .failed
      if failure == .signedOut { cache.clear() }
      if case .loaded = state, failure != .signedOut {
        refreshFailure = failure
      } else {
        state = .failed(failure)
      }
    }
  }
}
