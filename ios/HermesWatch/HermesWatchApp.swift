import SwiftUI

@main
struct HermesWatchApp: App {
  private let client: HermesClient = Self.makeClient()

  var body: some Scene {
    WindowGroup {
      ThreadListView(model: ThreadListModel(client: client))
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
