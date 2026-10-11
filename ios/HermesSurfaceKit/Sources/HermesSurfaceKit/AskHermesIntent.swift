import AppIntents
import Foundation

/// Asks Hermes a question without opening the app and says the reply. It runs
/// while the device is locked, as the user chose: it only sends what was said
/// and speaks what came back, and it cannot answer an approval or a question
/// of the agent, so a dangerous command still needs the unlocked phone. With
/// App Lock on it does not answer; it hands the question to the app, unsent.
struct AskHermesIntent: AppIntent {
  static let title: LocalizedStringResource = "Ask Hermes"
  static let description = IntentDescription(
    "Asks Hermes a question and says the answer, without opening the app.")
  static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
  static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

  @Parameter(title: "Question", requestValueDialog: "What do you want to ask Hermes?")
  var question: String

  @Parameter(title: "Profile", description: "The Hermes profile; the app's current one if empty.")
  var profile: ProfileEntity?

  @Parameter(
    title: "Chat", description: "Continues this chat instead of starting a new one.")
  var chat: ChatEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Ask Hermes \(\.$question)") {
      \.$profile
      \.$chat
    }
  }

  /// The chat is continued in its own profile and the Profile ignored; a new
  /// chat goes to the Profile, else the one the app last showed.
  func target(in directory: IntentDirectory) -> (profile: String?, chatID: String?) {
    if let chat { return (chat.profile, chat.id) }
    return (profile?.id ?? directory.currentProfile, nil)
  }

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let deadline = ContinuousClock.now + AskHermes.window
    let target = target(in: .current())
    let answer = await AskHermes.answer(
      question: question, profile: target.profile, chatID: target.chatID, deadline: deadline)
    if answer.outcome == .appLocked {
      try await continueInForeground(
        IntentDialog(stringLiteral: AskAnswer.sentence(for: .appLocked)), alwaysConfirm: true)
      await AskHermes.service?.open(
        AskHermes.handOverLink(profile: target.profile, question: question))
      return .result(value: "", dialog: IntentDialog(stringLiteral: "Opening Hermes."))
    }
    return .result(value: answer.output, dialog: IntentDialog(stringLiteral: answer.spoken))
  }
}
