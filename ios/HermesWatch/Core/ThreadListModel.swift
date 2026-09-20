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
  let client: HermesClient

  init(client: HermesClient) {
    self.client = client
  }

  func load() async {
    do {
      state = .loaded(try await client.threads())
    } catch {
      state = .failed(error as? HermesClientError ?? .failed)
    }
  }
}
