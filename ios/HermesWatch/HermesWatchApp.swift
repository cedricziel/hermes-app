import SwiftUI
import WatchConnectivity

@main
struct HermesWatchApp: App {
  private let client: HermesClient = Self.makeClient()

  init() {
    #if DEBUG
      DemoClient.seedComplication()
    #endif
  }

  var body: some Scene {
    WindowGroup {
      ThreadListView(model: ThreadListModel(client: client))
        .onOpenURL { LaunchRequests.shared.open($0) }
    }
    // The phone's status for the complications wakes the app in the background
    // and arrives through the session's delegate; the task is held until the
    // system has nothing more to deliver, or for a while at most.
    .backgroundTask(.watchConnectivity) {
      let deadline = Date().addingTimeInterval(25)
      while WCSession.default.hasContentPending, Date() < deadline {
        try? await Task.sleep(for: .milliseconds(500))
      }
    }
  }

  private static func makeClient() -> HermesClient {
    #if DEBUG
      if DemoClient.enabled { return DemoClient() }
    #endif
    return CachingClient(
      inner: RelayClient(
        transport: ReportingTransport(inner: WCSessionTransport(), reports: DeliveryReports(defaults: .standard))
      ),
      cache: FileChatCache.standard
    )
  }
}
