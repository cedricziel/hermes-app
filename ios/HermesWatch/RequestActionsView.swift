import SwiftUI

struct RequestActionsView: View {
  @Binding var draft: WatchRequestDraft?
  let answer: (WatchRequestAnswer) -> Void
  let checkStatus: () -> Void

  private func mutate(_ action: (inout WatchRequestDraft) -> WatchRequestAnswer?) {
    guard var current = draft else { return }
    let result = action(&current)
    draft = current
    if let result { answer(result) }
  }

  var body: some View {
    if let current = draft, let details = current.details {
      VStack(alignment: .leading, spacing: 12) {
        if details.kind == .approval {
          Text(details.command)
          if !details.description.isEmpty { Text(details.description) }
          if let choice = current.confirmationChoice {
            Text("Confirm \(label(choice))")
            Text("Scope: \(scope(choice))")
            Button("Confirm \(label(choice))") { mutate { $0.confirmApproval() } }
              .accessibilityHint("Approves the full command shown above for \(scope(choice))")
              .disabled(current.pending || current.needsStatusCheck)
            Button("Cancel", role: .cancel) { mutate { $0.cancelConfirmation(); return nil } }
              .accessibilityHint("Sends no answer")
          } else {
            ForEach(details.choices, id: \.self) { choice in
              Button(label(choice), role: choice == "deny" ? .destructive : nil) { mutate { $0.activateApproval(choice) } }
                .accessibilityHint(choice == "deny" ? "Denies this command immediately" : "Reviews the full command and \(scope(choice)) before approval")
                .disabled(current.pending || current.needsStatusCheck)
            }
          }
        } else if let question = current.question {
          Text("Question \(current.questionIndex + 1) of \(details.questions.count)")
          Text(question.prompt)
          if question.choices.isEmpty {
            TextField("Your answer", text: Binding(get: { draft?.text ?? "" }, set: { draft?.text = $0 }))
              .accessibilityLabel("Answer to the current question")
              .disabled(current.pending || current.needsStatusCheck)
          } else {
            ForEach(question.choices, id: \.self) { value in
              Button {
                mutate { $0.toggle(value); return question.multiSelect ? nil : $0.submitQuestion() }
              } label: {
                HStack { Text(value); if current.selection.contains(value) { Image(systemName: "checkmark") } }
              }
              .accessibilityLabel(value)
              .accessibilityValue(current.selection.contains(value) ? "Selected" : "Not selected")
              .accessibilityHint(question.multiSelect ? "Changes selection. Submit sends selected answers" : "Answers this question")
              .disabled(current.pending || current.needsStatusCheck)
            }
          }
          if question.multiSelect || question.choices.isEmpty {
            Button("Submit answer") { mutate { $0.submitQuestion() } }
              .accessibilityHint("Sends your answer to this question")
              .disabled(current.pending || current.needsStatusCheck)
          }
        } else { Text("Questions answered") }
        if current.pending { Text("Sending answer…") }
        if current.needsStatusCheck {
          Text("Answer status unknown. Check the current request before continuing.")
          Button("Check request status", action: checkStatus)
            .accessibilityHint("Checks status without sending the answer again")
        }
      }
    } else { Text("Answer in Hermes on iPhone") }
  }

  private func label(_ choice: String) -> String {
    switch choice { case "once": return "Allow once"; case "session": return "Allow for session"; case "always": return "Always allow"; default: return "Deny" }
  }
  private func scope(_ choice: String) -> String {
    switch choice { case "once": return "this command once"; case "session": return "this session"; default: return "future matching commands" }
  }
}

#if DEBUG
  private struct RequestPreview: View {
    @State var draft: WatchRequestDraft?
    var body: some View { ScrollView { RequestActionsView(draft: $draft, answer: { _ in }, checkStatus: {}) } }
  }
  #Preview("Approval, long command") { RequestPreview(draft: WatchRequestDraft(details: RequestFixtures.approval(long: true))).environment(\.dynamicTypeSize, .accessibility5) }
  #Preview("Questions") { RequestPreview(draft: WatchRequestDraft(details: RequestFixtures.questions())) }
  #Preview("Old phone fallback") { RequestPreview(draft: nil) }
#endif
