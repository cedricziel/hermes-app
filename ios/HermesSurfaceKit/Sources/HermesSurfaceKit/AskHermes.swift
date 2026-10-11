import Foundation

// What "Ask Hermes" says and when. The Runner's bridge runs the turn in Dart;
// everything here is the part that has to be right without the app: the
// clock, the words for each outcome and the link that hands a question to the
// app. No UIKit, no Flutter, so `swift test` covers it.

/// How a question ended, named as the Dart side names it.
public enum AskOutcome: String, Sendable, CaseIterable {
  case answered
  case stillWorking = "still_working"
  case needsYou = "needs_you"
  case failed
  case signedOut = "signed_out"
  case deviceLocked = "device_locked"
  case unreachable
  /// The Dart side could not be started. Only Swift reports it.
  case unavailable
  case appLocked = "app_locked"
}

/// What the intent has to say about a question.
public struct AskAnswer: Equatable, Sendable {
  public let outcome: AskOutcome
  /// The reply's text, for an answered question; empty otherwise.
  public let text: String

  public init(_ outcome: AskOutcome, text: String = "") {
    self.outcome = outcome
    self.text = text
  }

  /// A reply from the Dart side: `{outcome, text?}`. Anything else means
  /// the ask failed.
  public init(channelReply reply: Any?) {
    let map = reply as? [String: Any]
    let outcome = (map?["outcome"] as? String).flatMap(AskOutcome.init(rawValue:)) ?? .failed
    self.init(outcome, text: outcome == .answered ? (map?["text"] as? String) ?? "" : "")
  }

  /// What Shortcuts receives: the reply as Hermes wrote it, or the sentence
  /// Siri says. A command or a question the agent asked never gets here.
  public var output: String {
    outcome == .answered ? text : Self.sentence(for: outcome)
  }

  /// What Siri says: the reply with its Markdown removed.
  public var spoken: String {
    outcome == .answered ? SpokenText.plain(text) : Self.sentence(for: outcome)
  }

  public static func sentence(for outcome: AskOutcome) -> String {
    switch outcome {
    case .answered: return ""
    case .stillWorking: return "Still working — I'll notify you."
    case .needsYou: return "Hermes needs your answer. Open the chat in Hermes."
    case .failed: return "Hermes couldn't answer."
    case .signedOut: return "Sign in to Hermes first."
    case .deviceLocked: return "Unlock your iPhone first."
    case .unreachable: return "Can't reach your Hermes server."
    case .unavailable: return "Hermes isn't available right now. Open Hermes to check."
    case .appLocked: return "Continue in Hermes to ask."
    }
  }
}

/// Runs the turn for the intent. The Runner's bridge is the only one.
public protocol AskTurnService: AnyObject {
  /// Sends [question] and answers within [deadline]: the reply, why it could
  /// not be asked, or that the reply will come later. A chat is continued in
  /// its own profile; without one a new chat starts in [profile].
  func ask(question: String, profile: String?, chatID: String?, deadline: ContinuousClock.Instant)
    async -> AskAnswer

  /// Opens a `hermes://` link, once the app is in front.
  func open(_ url: URL) async
}

public enum AskHermes {
  /// How long Siri may wait for a reply: it gives an intent a little over 30
  /// seconds, and the engine's start is paid out of the same window.
  public static let window: Duration = .seconds(25)

  /// The bridge the Runner installs at launch.
  public static var service: AskTurnService?

  /// The link that opens a new chat with [question] in the composer, unsent.
  public static func handOverLink(profile: String?, question: String) -> URL {
    DeepLink.newChat(profile: profile, prompt: question)
  }

  /// Asks [service], giving up on the answer at [deadline] with "still
  /// working". The ask itself goes on: the question is sent whatever Siri
  /// hears, and the reply arrives as a notification.
  public static func answer(
    question: String, profile: String?, chatID: String?, deadline: ContinuousClock.Instant,
    service: AskTurnService? = AskHermes.service, clock: ContinuousClock = ContinuousClock()
  ) async -> AskAnswer {
    guard let service else { return AskAnswer(.unavailable) }
    return await race(until: deadline, clock: clock) {
      await service.ask(question: question, profile: profile, chatID: chatID, deadline: deadline)
    }
  }

  /// The first of [work]'s answer and "still working" at [deadline]. [work]
  /// is not cancelled when the deadline wins.
  static func race(
    until deadline: ContinuousClock.Instant, clock: ContinuousClock = ContinuousClock(),
    work: @escaping @Sendable () async -> AskAnswer
  ) async -> AskAnswer {
    await withCheckedContinuation { continuation in
      let once = Once(continuation)
      let timer = Task {
        do { try await clock.sleep(until: deadline) } catch { return }
        once.resume(AskAnswer(.stillWorking))
      }
      Task {
        once.resume(await work())
        timer.cancel()
      }
    }
  }
}

/// Resumes a continuation the first time it is asked to, however many tasks
/// race for it.
private final class Once: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<AskAnswer, Never>?

  init(_ continuation: CheckedContinuation<AskAnswer, Never>) {
    self.continuation = continuation
  }

  func resume(_ answer: AskAnswer) {
    lock.lock()
    let taken = continuation
    continuation = nil
    lock.unlock()
    taken?.resume(returning: answer)
  }
}

/// A reply's Markdown as Siri should say it: the words, without the marks.
public enum SpokenText {
  private static let rules: [(pattern: String, template: String)] = [
    (#"(?m)^[ \t]*```[^\n]*\n?"#, ""),
    (#"!\[([^\]\n]*)\]\([^)\n]*\)"#, "$1"),
    (#"\[([^\]\n]+)\]\([^)\n]*\)"#, "$1"),
    (#"(?m)^[ \t]*([-*_][ \t]*){3,}$"#, ""),
    (#"\*\*([^\n]+?)\*\*"#, "$1"),
    (#"__([^\n]+?)__"#, "$1"),
    (#"~~([^\n]+?)~~"#, "$1"),
    (#"(?<![\w*])\*(?=\S)([^*\n]+?)(?<=\S)\*(?![\w*])"#, "$1"),
    (#"(?<![\w_])_(?=\S)([^_\n]+?)(?<=\S)_(?![\w_])"#, "$1"),
    (#"`([^`\n]+)`"#, "$1"),
    (#"(?m)^[ \t]{0,3}#{1,6}[ \t]+"#, ""),
    (#"(?m)^([ \t]*)[-*+][ \t]+"#, "$1"),
    (#"(?m)^[ \t]{0,3}>[ \t]?"#, ""),
    (#"\n{3,}"#, "\n\n"),
  ]

  public static func plain(_ markdown: String) -> String {
    var text = markdown
    for (pattern, template) in rules {
      text = text.replacingOccurrences(
        of: pattern, with: template, options: .regularExpression)
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
