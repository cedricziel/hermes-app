import SwiftUI
import WatchConnectivity

@main
struct HermesWatchApp: App {
  private let client: HermesClient = Self.makeClient()

  init() {
    _ = WatchSessionState.shared.start(receivedSession: WCSession.default.receivedApplicationContext) {
      FileChatCache.standard.clear()
      try? FilePendingSendStore.standard.invalidateAll()

      LaunchRequests.shared.pending = nil
      ComplicationUpdates.clear()
    }
    FileChatCache.standard.retryCleanup()
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
      // `hasContentPending` says nothing before the session is active.
      let deadline = Date().addingTimeInterval(25)
      let session = WCSession.default
      while session.activationState != .activated, Date() < deadline {
        try? await Task.sleep(for: .milliseconds(200))
      }
      while session.hasContentPending, Date() < deadline {
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
        transport: ReportingTransport(inner: WCSessionTransport(), reports: DeliveryReports(defaults: .standard)),
        session: .shared
      ),
      cache: FileChatCache.standard,
      session: .shared
    )
  }
}
