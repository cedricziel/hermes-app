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

  init(client: HermesClient) {
    self.client = client
  }

  /// Shows the chats saved last time, if there are any, until the phone
  /// answers.
  func load() async {
    if state == .loading, let saved = client.savedThreads() { state = .loaded(saved) }
    do {
      state = .loaded(try await client.threads())
      refreshFailure = nil
    } catch {
      let failure = error as? HermesClientError ?? .failed
      if case .loaded = state, failure != .signedOut {
        refreshFailure = failure
      } else {
        state = .failed(failure)
      }
    }
  }
}
