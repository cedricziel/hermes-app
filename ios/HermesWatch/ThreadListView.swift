import SwiftUI

struct ThreadListView: View {
  /// Where a push goes: a new chat or an existing one, by thread id.
  private enum Route: Hashable {
    case newChat
    case thread(String)
  }

  @State var model: ThreadListModel
  @State private var path: [Route] = []

  var body: some View {
    NavigationStack(path: $path) {
      Group {
        switch model.state {
        case .loading:
          ProgressView()
        case .failed(let error):
          ErrorView(error: error) { Task { await model.load() } }
        case .loaded(let threads):
          list(threads)
        }
      }
      .navigationTitle("Hermes")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          NavigationLink(value: Route.newChat) {
            Image(systemName: "square.and.pencil")
          }
        }
      }
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .newChat:
          ConversationView(model: ConversationModel(client: model.client, threadId: nil))
        case .thread(let id):
          ConversationView(model: ConversationModel(client: model.client, threadId: id))
        }
      }
    }
    .task { await model.load() }
    // A chat started or continued in a conversation belongs in the list once
    // the user is back on it.
    .onChange(of: path.isEmpty) { _, isEmpty in
      if isEmpty { Task { await model.load() } }
    }
  }

  private func list(_ threads: [ThreadSummary]) -> some View {
    List {
      if threads.isEmpty {
        Text("No chats yet.")
      }
      ForEach(threads) { thread in
        NavigationLink(value: Route.thread(thread.id)) {
          Label {
            Text(thread.title).lineLimit(2)
          } icon: {
            if thread.pinned { Image(systemName: "pin.fill") }
          }
        }
      }
    }
    .refreshable { await model.load() }
  }
}
