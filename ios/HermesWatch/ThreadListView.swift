import SwiftUI

struct ThreadListView: View {
  /// Where a push goes: a new chat or an existing one, by thread id.
  private enum Route: Hashable {
    /// Each new chat gets its own id, so a shortcut run while one is open
    /// still starts a fresh one.
    case newChat(UUID = UUID())
    case voiceChat(UUID = UUID())
    case thread(id: String, title: String, handoff: HandoffTarget?)
  }

  @State var model: ThreadListModel
  var launchRequests = LaunchRequests.shared
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
          NavigationLink(value: Route.newChat()) {
            Image(systemName: "square.and.pencil")
          }
        }
      }
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .newChat:
          ConversationView(model: ConversationModel(client: model.client, threadId: nil))
        case .voiceChat:
          ConversationView(
            model: ConversationModel(client: model.client, threadId: nil),
            startRecording: true
          )
        case .thread(let id, let title, let handoff):
          ConversationView(
            model: ConversationModel(client: model.client, threadId: id, handoff: handoff),
            title: title
          )
        }
      }
    }
    .task {
      #if DEBUG
        if DemoClient.opensChat, let thread = DemoClient.threads.first {
          path = [.thread(id: thread.id, title: thread.title, handoff: thread.handoff)]
        }
      #endif
      await model.load()
    }
    .onChange(of: launchRequests.pending, initial: true) { _, request in
      guard let request else { return }
      launchRequests.pending = nil
      path = [request == .voiceChat ? .voiceChat() : .newChat()]
    }
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
        NavigationLink(value: Route.thread(id: thread.id, title: thread.title, handoff: thread.handoff)) {
          ThreadRow(thread: thread)
        }
      }
    }
    .refreshable { await model.load() }
    .safeAreaInset(edge: .bottom) {
      if let failure = model.refreshFailure {
        Text("Saved chats. \(failure.message)")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal)
          .background(.background)
      }
    }
  }
}

private struct ThreadRow: View {
  let thread: ThreadSummary

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        if thread.pinned {
          Image(systemName: "pin.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
            .accessibilityLabel("Pinned")
        }
        Text(thread.title).lineLimit(2)
      }
      if let updatedAt = thread.updatedAt {
        Text(updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
  }
}
