import Foundation
import Observation

@MainActor
protocol WatchRequestServing {
  func requestDetails(threadId: String, requestId: String) async throws -> WatchRequestDetails?
  func answerRequest(threadId: String, requestId: String, fingerprint: String, answer: WatchRequestAnswer) async throws -> String
}

extension WatchRequestServing {
  func requestDetails(threadId: String, requestId: String) async throws -> WatchRequestDetails? { throw HermesClientError.unavailable }
  func answerRequest(threadId: String, requestId: String, fingerprint: String, answer: WatchRequestAnswer) async throws -> String { throw HermesClientError.unavailable }
}

@MainActor
@Observable
final class RequestActionsModel {
  var draft: WatchRequestDraft?
  private(set) var loading = false
  private(set) var fallback = false
  private let client: WatchRequestServing
  private let session: WatchSessionState
  private let access: WatchRequestAccess
  private var cleanupId: UUID?
  private var accessId: UUID?
  private var generation = 0
  private var threadId: String?
  private var requestId: String?
  private var uncertain = false
  private var submittedQuestion: (qid: String, fingerprint: String)?

  init(client: WatchRequestServing, session: WatchSessionState, access: WatchRequestAccess) {
    self.client = client
    self.session = session
    self.access = access
    attach()
  }

  func attach() {
    if cleanupId == nil { cleanupId = session.register { [weak self] in self?.clear() } }
    if accessId == nil { accessId = access.register { [weak self] in self?.clear() } }
  }

  func clear() {
    generation += 1
    draft?.clear()
    draft = nil
    loading = false
    fallback = false
    threadId = nil
    requestId = nil
    uncertain = false
    submittedQuestion = nil
  }

  func detach() {
    clear()
    if let cleanupId { session.unregister(cleanupId) }
    if let accessId { access.unregister(accessId) }
    cleanupId = nil
    accessId = nil
  }

  func load(threadId: String, requestId: String) async {
    guard !loading, access.allowed, session.owns(threadId) else { fallback = true; return }
    if self.requestId != requestId || self.threadId != threadId {
      clear()
      self.threadId = threadId
      self.requestId = requestId
    }
    loading = true
    let token = generation
    let epoch = access.epoch
    do {
      let details = try await client.requestDetails(threadId: threadId, requestId: requestId)
      guard token == generation, epoch == access.epoch, access.allowed, session.owns(threadId) else { return }
      loading = false
      guard let details, details.requestId == requestId, !details.fingerprint.isEmpty else { draft = nil; fallback = true; return }
      if uncertain, details.kind == .question, details.batch,
        let submittedQuestion, details.accepted.contains(submittedQuestion.qid),
        details.acceptedFingerprints[submittedQuestion.qid] == submittedQuestion.fingerprint {
        uncertain = false
        self.submittedQuestion = nil
      }
      var next = WatchRequestDraft(details: details)
      if uncertain { next.uncertain() }
      draft = next
      fallback = false
    } catch {
      guard token == generation else { return }
      loading = false
      draft = nil
      fallback = true
    }
  }

  func submit(_ answer: WatchRequestAnswer) async {
    guard !uncertain, let details = draft?.details, let threadId, let requestId,
      access.allowed, session.owns(threadId), draft?.pending == true else { return }
    let token = generation
    let epoch = access.epoch
    // Once submitted, a lost response must never make the same action retryable.
    uncertain = true
    if case .question(let qid, _) = answer, details.batch {
      submittedQuestion = (qid, details.fingerprint)
    } else { submittedQuestion = nil }
    do {
      let status = try await client.answerRequest(threadId: threadId, requestId: requestId, fingerprint: details.fingerprint, answer: answer)
      guard token == generation, epoch == access.epoch, access.allowed, session.owns(threadId) else { return }
      if status == "accepted" {
        uncertain = false
        submittedQuestion = nil
        if details.kind == .question && details.batch {
          draft?.accepted()
          await load(threadId: threadId, requestId: requestId)
        } else { draft = nil }
      } else if status == "expired" { draft = nil; uncertain = false }
      else { draft?.uncertain() }
    } catch {
      guard token == generation else { return }
      draft?.uncertain()
    }
  }

  func checkStatus() async {
    guard let threadId, let requestId else { return }
    await load(threadId: threadId, requestId: requestId)
  }
}
