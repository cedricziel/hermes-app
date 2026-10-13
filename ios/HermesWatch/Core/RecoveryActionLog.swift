import OSLog

struct RecoveryActionLog {
  enum Action: String { case checkResult = "check_result", resendConfirmed = "resend_confirmed" }
  enum Outcome: String { case pending, uncertain, notSent = "not_sent", completed, failed, unsupported, storageFailed = "storage_failed" }
  private let emit: ([String: String]) -> Void

  init(emit: @escaping ([String: String]) -> Void = { values in
    Logger(subsystem: "app.hermes.watch", category: "recovery").notice("Recovery action=\(values["action"]!, privacy: .public) outcome=\(values["outcome"]!, privacy: .public)")
  }) { self.emit = emit }

  func record(_ action: Action, _ outcome: Outcome) {
    emit(["action": action.rawValue, "outcome": outcome.rawValue])
  }
}
