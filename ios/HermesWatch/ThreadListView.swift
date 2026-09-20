import SwiftUI

struct ThreadListView: View {
  @State var model: ThreadListModel

  var body: some View {
    NavigationStack {
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
          NavigationLink {
            ConversationView(model: ConversationModel(client: model.client, threadId: nil))
          } label: {
            Image(systemName: "square.and.pencil")
          }
        }
      }
    }
    .task { await model.load() }
  }

  @ViewBuilder
  private func list(_ threads: [ThreadSummary]) -> some View {
    if threads.isEmpty {
      Text("No chats yet.")
    } else {
      List(threads) { thread in
        NavigationLink {
          ConversationView(model: ConversationModel(client: model.client, threadId: thread.id))
        } label: {
          Label {
            Text(thread.title).lineLimit(2)
          } icon: {
            if thread.pinned { Image(systemName: "pin.fill") }
          }
        }
      }
      .refreshable { await model.load() }
    }
  }
}
