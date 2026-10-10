import SwiftUI

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
