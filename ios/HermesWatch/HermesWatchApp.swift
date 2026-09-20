import SwiftUI

@main
struct HermesWatchApp: App {
  private let client: HermesClient = RelayClient(transport: WCSessionTransport())

  var body: some Scene {
    WindowGroup {
      ThreadListView(model: ThreadListModel(client: client))
    }
  }
}
