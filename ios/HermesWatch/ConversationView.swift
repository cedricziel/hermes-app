import SwiftUI

struct ConversationView: View {
  @State var model: ConversationModel
  @State private var draft = ""

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if model.phase == .loading {
            ProgressView()
          }
          ForEach(model.messages) { message in
            MessageBubble(message: message).id(message.id)
          }
          if model.phase == .sending {
            Text("Hermes is thinking…").foregroundStyle(.secondary)
          }
          if case .failed(let error) = model.phase {
            ErrorView(error: error) { Task { await retry() } }
          }
          TextField("Reply", text: $draft)
            .onSubmit { Task { await submit() } }
            .disabled(model.phase == .sending)
            .id("composer")
        }
      }
      .onChange(of: model.messages.count) {
        withAnimation { proxy.scrollTo("composer") }
      }
    }
    .navigationTitle("Chat")
    .navigationBarTitleDisplayMode(.inline)
    .task { await model.load() }
  }

  private func submit() async {
    let text = draft
    draft = ""
    await model.send(text)
  }

  private func retry() async {
    if let unsent = model.unsent {
      await model.send(unsent)
    } else {
      await model.load()
    }
  }
}

private struct MessageBubble: View {
  let message: ChatMessage

  var body: some View {
    Text(message.content)
      .padding(8)
      .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
      .background(
        message.role == .user ? Color.accentColor.opacity(0.35) : Color.gray.opacity(0.25),
        in: RoundedRectangle(cornerRadius: 10)
      )
  }
}
