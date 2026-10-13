import SwiftUI

struct ThreadListView: View {
  /// Where a push goes: a new chat or an existing one, by thread id.
  private enum Route: Hashable {
    /// Each new chat gets its own id, so a shortcut run while one is open
    /// still starts a fresh one.
    case newChat(UUID = UUID())
    case voiceChat(UUID = UUID())
    case thread(id: String, title: String, handoff: HandoffTarget?, updatedAt: Date?)
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
          .accessibilityLabel("New chat")
          .accessibilityHint("Starts a chat using the active profile")
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
        case .thread(let id, let title, let handoff, let updatedAt):
          ConversationView(
            model: ConversationModel(client: model.client, threadId: id, handoff: handoff,
              onFreshMessagesLoaded: { model.markSeen(threadId: id, updatedAt: updatedAt) }),
            title: title
          )
        }
      }
    }
    .task {
      #if DEBUG
        if DemoClient.opensChat, let thread = DemoClient.threads.first {
          if ProcessInfo.processInfo.environment["HERMES_WATCH_DEMO"] == "recovery_no_thread" { path = [.newChat()] }
          else { path = [.thread(id: thread.id, title: thread.title, handoff: thread.handoff, updatedAt: thread.updatedAt)] }
        }
      #endif
      await model.load()
    }
    .onChange(of: launchRequests.pending, initial: true) { _, request in
      guard let request else { return }
      launchRequests.pending = nil
      switch request {
      case .newChat: path = [.newChat()]
      case .voiceChat: path = [.voiceChat()]
      case .thread(let id, let title): path = [.thread(id: id, title: title, handoff: nil, updatedAt: model.listedUpdateTime(threadId: id))]
      }
    }
    // A chat started or continued in a conversation belongs in the list once
    // the user is back on it.
    .onChange(of: path.isEmpty) { _, isEmpty in
      if isEmpty { Task { await model.load() } }
    }
  }

  private func list(_ threads: [ThreadSummary]) -> some View {
    List {
      Text(model.activeProfile.map { "\(model.showingSaved ? "Saved profile" : "New chats use"): \($0)" } ?? "New chat profile unknown")
        .font(.footnote)
        .foregroundStyle(.secondary)
      if threads.isEmpty {
        Text("No chats yet.")
      }
      ForEach(threads) { thread in
        NavigationLink(value: Route.thread(id: thread.id, title: thread.title, handoff: thread.handoff, updatedAt: thread.updatedAt)) {
          ThreadRow(thread: thread, saved: model.showingSaved, updated: model.isUpdated(thread))
        }
        .accessibilityHint("Opens this chat")
      }
      if model.showingSaved {
        Text("\(ThreadGlancePresentation.savedFreshness(model.fetchedAt)) \(model.refreshFailure?.message ?? "Refreshing chats.")")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .refreshable { await model.load() }
  }
}

private struct ThreadRow: View {
  let thread: ThreadSummary
  let saved: Bool
  let updated: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        if thread.pinned {
          Image(systemName: "pin.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
            .accessibilityHidden(true)
        }
        Text(thread.title).fixedSize(horizontal: false, vertical: true)
      }
      Text(ThreadGlancePresentation.status(thread, saved: saved))
        .font(.footnote)
        .foregroundStyle(.secondary)
      if updated {
        Text("Updated on this watch").font(.footnote)
      }
      if let updatedAt = thread.updatedAt {
        Text(updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(ThreadGlancePresentation.accessibilityLabel(thread, saved: saved, updated: updated))
  }
}

#if DEBUG
  #Preview("Maximum text and accessible status") {
    ThreadListView(model: ThreadListModel(client: DemoClient(glanceMode: "glance_accessibility")))
      .environment(\.dynamicTypeSize, .accessibility5)
  }

  #Preview("Saved chats and failed refresh") {
    ThreadListView(model: ThreadListModel(client: DemoClient(glanceMode: "glance_failed")))
  }

  #Preview("Older metadata payload") {
    ThreadListView(model: ThreadListModel(client: DemoClient(glanceMode: "glance_old_payload")))
  }
#endif
