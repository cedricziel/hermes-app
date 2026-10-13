import Foundation

struct WatchRequestDetails: Equatable {
  struct Question: Equatable {
    let qid: String
    let prompt: String
    let choices: [String]
    let multiSelect: Bool
  }
  enum Kind: String { case approval, question }
  let kind: Kind
  let requestId: String
  let fingerprint: String
  let command: String
  let description: String
  let choices: [String]
  let batch: Bool
  let questions: [Question]
  let accepted: Set<String>
  let acceptedFingerprints: [String: String]

  init(row: [String: Any]) throws {
    guard JSONSerialization.isValidJSONObject(row),
      let size = try? JSONSerialization.data(withJSONObject: row).count, size < 60_000,
      let kindText = row["kind"] as? String, let kind = Kind(rawValue: kindText),
      let id = row["requestId"] as? String, !id.isEmpty else { throw HermesClientError.unavailable }
    self.kind = kind
    requestId = id
    fingerprint = row["fingerprint"] as? String ?? ""
    let batch = row["batch"] as? Bool ?? false
    self.batch = batch
    let accepted = Set(row["accepted"] as? [String] ?? [])
    self.accepted = accepted
    acceptedFingerprints = row["acceptedFingerprints"] as? [String: String] ?? [:]
    description = row["description"] as? String ?? ""
    command = row["command"] as? String ?? ""
    choices = row["choices"] as? [String] ?? []
    if kind == .approval {
      guard !command.isEmpty, !choices.isEmpty,
        Set(choices).count == choices.count,
        choices.allSatisfy({ ["once", "session", "always", "deny"].contains($0) }) else { throw HermesClientError.unavailable }
      questions = []
    } else {
      guard let rows = row["questions"] as? [[String: Any]], !rows.isEmpty,
        batch || rows.count == 1 else { throw HermesClientError.unavailable }
      questions = try rows.map { question in
        guard let qid = question["qid"] as? String, !batch || !qid.isEmpty,
          let prompt = question["prompt"] as? String, !prompt.isEmpty,
          let values = question["choices"] as? [String],
          Set(values).count == values.count, values.allSatisfy({ !$0.isEmpty }),
          let multi = question["multiSelect"] as? Bool else { throw HermesClientError.unavailable }
        return Question(qid: qid, prompt: prompt, choices: values, multiSelect: multi)
      }
      guard Set(questions.map(\.qid)).count == questions.count,
        accepted.isSubset(of: Set(questions.map(\.qid))) else { throw HermesClientError.unavailable }
    }
  }
}

enum WatchRequestAnswer: Equatable {
  case approval(choice: String, command: String)
  case question(qid: String, values: [String])

  var fields: [String: Any] {
    switch self {
    case .approval(let choice, let command): return ["choice": choice, "command": command]
    case .question(let qid, let values): return ["qid": qid, "values": values]
    }
  }
}

struct WatchRequestDraft {
  private(set) var details: WatchRequestDetails?
  private(set) var confirmationChoice: String?
  private(set) var questionIndex = 0
  private(set) var selection: Set<String> = []
  var text = ""
  private(set) var pending = false
  private(set) var needsStatusCheck = false

  init(details: WatchRequestDetails) {
    self.details = details
    while questionIndex < details.questions.count && details.accepted.contains(details.questions[questionIndex].qid) { questionIndex += 1 }
  }

  var question: WatchRequestDetails.Question? {
    guard let details, questionIndex < details.questions.count else { return nil }
    return details.questions[questionIndex]
  }

  mutating func activateApproval(_ choice: String) -> WatchRequestAnswer? {
    guard let details, details.kind == .approval, !pending, !needsStatusCheck,
      details.choices.contains(choice) else { return nil }
    if choice != "deny" { confirmationChoice = choice; return nil }
    pending = true
    return .approval(choice: choice, command: details.command)
  }

  mutating func cancelConfirmation() { confirmationChoice = nil }

  mutating func confirmApproval() -> WatchRequestAnswer? {
    guard let details, let choice = confirmationChoice, !pending, !needsStatusCheck else { return nil }
    confirmationChoice = nil
    pending = true
    return .approval(choice: choice, command: details.command)
  }

  mutating func toggle(_ value: String) {
    guard let question, question.choices.contains(value), !pending, !needsStatusCheck else { return }
    if question.multiSelect {
      if !selection.insert(value).inserted { selection.remove(value) }
    } else { selection = [value] }
  }

  mutating func submitQuestion() -> WatchRequestAnswer? {
    guard let question, !pending, !needsStatusCheck else { return nil }
    let values = question.choices.isEmpty ? [text] : question.choices.filter { selection.contains($0) }
    guard !values.isEmpty, !values.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
      question.multiSelect || values.count == 1 else { return nil }
    pending = true
    return .question(qid: question.qid, values: values)
  }

  mutating func accepted() {
    guard !needsStatusCheck else { return }
    pending = false
    selection.removeAll()
    text = ""
    questionIndex += 1
  }

  mutating func uncertain() { pending = false; needsStatusCheck = true; confirmationChoice = nil }
  mutating func clear() { details = nil; confirmationChoice = nil; selection.removeAll(); text = ""; pending = false; needsStatusCheck = false }
}
