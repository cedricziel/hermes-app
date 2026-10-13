import Foundation
import Observation

@MainActor
@Observable
final class ConversationModel {
  enum Phase: Equatable {
    case loading, idle, transcribing, sending
    case waiting(SendResult.Waiting)
    case failed(HermesClientError)
  }

  private(set) var permitsOriginalTitle = true
  private(set) var threadId: String?
  private(set) var handoff: HandoffTarget?
  private(set) var messages: [ChatMessage] = []
  private(set) var phase = Phase.idle
  private(set) var unsent: String?
  private(set) var unsentVoice: Data?
  private(set) var recovery: PendingSendRecord?
  private(set) var checkAttempted = false
  private(set) var resendConfirmation = false
  private(set) var recoveryAvailable = false
  private var replacementText: String?
  private var detached = false
  private var terminalCleanup: [String: PendingSendRecord] = [:]
  private var currentSend: UUID?
  private let session: WatchSessionState
  private var cleanupId: UUID?
  private let client: HermesClient
  private let store: PendingSendStore
  private let log: RecoveryActionLog
  static let waitingLimit: TimeInterval = 20 * 60

  init(client: HermesClient, threadId: String?, handoff: HandoffTarget? = nil,
    session: WatchSessionState? = nil, store: PendingSendStore? = nil,
    log: RecoveryActionLog = RecoveryActionLog()) {
    self.client = client
    self.threadId = threadId
    self.handoff = threadId == nil ? nil : handoff
    self.store = store ?? client.recoveryStore
    self.log = log
    if threadId != nil { phase = .loading }
    self.session = session ?? client.sessionState ?? WatchSessionState()
    cleanupId = self.session.register { [weak self] in self?.clearPrivateState() }
  }

  func load() async {
    guard session.usable else { return }
    let generation = session.generation
    phase = .loading
    do {
      retryTerminalCleanup()
      try restore()
      try await client.prepareRecovery()
      recoveryAvailable = true
      guard generation == session.generation else { return }
      try restore()
      if let threadId {
        if messages.isEmpty, let saved = client.savedMessages(threadId: threadId) { messages = saved }
        let loaded = try await client.messages(threadId: threadId)
        guard generation == session.generation else { return }
        messages = loaded
        appendRecoveryMessage()
      }
      phase = .idle
    } catch { fail(error, generation: generation) }
  }

  private func restore() throws {
    guard let context = session.contextId else { return }
    if recovery == nil {
      recovery = try store.records(contextId: context, revision: session.revision)
        .first { terminalCleanup[$0.sendId] == nil && ($0.threadId == threadId || (threadId == nil && $0.originalThreadId == nil)) }
    }
    appendRecoveryMessage()
  }

  private func appendRecoveryMessage() {
    guard let recovery, !messages.contains(where: { $0.id == recovery.localMessageId }) else { return }
    messages.append(ChatMessage(id: recovery.localMessageId, role: .user, content: recovery.text, at: recovery.createdAt))
  }

  func send(_ raw: String) async {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard session.usable, !text.isEmpty, !busy else { return }
    if let recovery, (!detached || text == recovery.text), recovery.recoveryState != .notSent {
      guard canSendAgain else { return }
      replacementText = text
      resendConfirmation = true
      return
    }
    await begin(text)
  }

  private func begin(_ text: String) async {
    let generation = session.generation
    phase = .sending
    do {
      try await client.prepareRecovery()
      recoveryAvailable = true
      guard generation == session.generation, session.usable, let context = session.contextId else { return }
      retryTerminalCleanup()
      let old = detached ? nil : recovery
      let sendId = UUID().uuidString
      let record = PendingSendRecord(sendId: sendId, contextId: context, revision: session.revision,
        profile: threadId.flatMap { WatchThreadId.decode($0)?.profile }, threadId: threadId,
        text: text, localMessageId: "local-\(sendId)", createdAt: Date(), recoveryState: .pending)
      try store.save(record)
      if let old, old.recoveryState == .notSent {
        try store.discard(sendId: old.sendId, contextId: old.contextId, revision: old.revision)
      }
      recovery = record
      detached = false
      checkAttempted = false
      unsent = nil
      appendRecoveryMessage()
      await deliver(record, retry: false)
    } catch { fail(error, generation: generation) }
  }

  func checkResult() async {
    guard !busy, let record = recovery, matches(record) else { return }
    checkAttempted = true
    let generation = session.generation
    do {
      try await client.prepareRecovery()
      guard generation == session.generation, matches(record) else { return }
      recoveryAvailable = true
      await deliver(record, retry: true, action: .checkResult)
    } catch {
      fail(error, generation: generation)
      log.record(.checkResult, (error as? HermesClientError) == .updateRequired ? .unsupported : .failed)
    }
  }

  var canCompose: Bool { !busy && (recovery == nil || detached || canSendAgain) }

  var canSendAgain: Bool { recoveryAvailable && (recovery?.recoveryState == .notSent || (recovery?.recoveryState == .uncertain && checkAttempted)) && !busy }

  func requestSendAgain() async {
    guard canSendAgain, let recovery else { return }
    if recovery.recoveryState == .notSent { await begin(recovery.text); return }
    replacementText = recovery.text
    resendConfirmation = true
  }

  func cancelSendAgain() { resendConfirmation = false; replacementText = nil }

  func confirmSendAgain() async {
    guard resendConfirmation, canSendAgain, let text = replacementText else { return }
    cancelSendAgain()
    await begin(text)
    log.record(.resendConfirmed, recoveryOutcome)
  }

  func forgetRecovery() async {
    guard !busy, let record = recovery, matches(record) else { return }
    do {
      try store.discard(sendId: record.sendId, contextId: record.contextId, revision: record.revision)
      recovery = nil
      checkAttempted = false
      cancelSendAgain()
      phase = .idle
      try? await client.forgetSend(sendId: record.sendId)
      if matches(record) { try restore() }
    } catch { phase = .failed(.recoveryStorage) }
  }

  func openRecoveryChat() async {
    guard let bound = recovery?.threadId else { return }
    threadId = bound
    await load()
  }

  private func deliver(_ original: PendingSendRecord, retry: Bool, action: RecoveryActionLog.Action? = nil) async {
    guard matches(original) else { return }
    let attempt = UUID()
    currentSend = attempt
    phase = .sending
    var record = original
    var accepted = false
    var notSent = false
    func owned() -> Bool { currentSend == attempt && matches(record) }
    do {
      var result = try await client.send(threadId: record.threadId, text: record.text, sendId: record.sendId, retry: retry, createdAt: record.createdAt)
      guard owned() else { return }
      let deadline = Date().addingTimeInterval(Self.waitingLimit)
      while let waiting = result.waiting, result.recoveryState == nil {
        accepted = true
        record.recoveryState = .pending
        record.threadId = result.threadId ?? record.threadId
        try store.save(record)
        recovery = record
        threadId = record.threadId
        handoff = result.handoff ?? handoff
        phase = waiting == .working ? .sending : .waiting(waiting)
        guard Date() < deadline else { throw HermesClientError.failed }
        result = try await client.send(threadId: record.threadId, text: record.text, sendId: record.sendId, retry: true, createdAt: record.createdAt)
        guard owned() else { return }
      }
      record.threadId = result.threadId ?? record.threadId
      if let state = result.recoveryState {
        accepted = state == .pending
        notSent = state == .notSent
        record.recoveryState = state
        try store.save(record)
        recovery = record
        threadId = record.threadId ?? threadId
        handoff = result.handoff ?? handoff
        phase = .idle
        currentSend = nil
        if let action { log.record(action, state == .pending ? .pending : state == .notSent ? .notSent : .uncertain) }
        return
      }
      complete(result, record: record)
      if let action { log.record(action, .completed) }
    } catch {
      guard owned() else { return }
      if (error as? PendingSendStoreError) == .invalidated {
        clearTerminalRecovery(record)
        return
      }
      if accepted { record.recoveryState = .pending }
      else if notSent || (retry && original.recoveryState == .notSent) { record.recoveryState = .notSent }
      else { record.recoveryState = .uncertain }
      do { try store.save(record) }
      catch PendingSendStoreError.invalidated { clearTerminalRecovery(record); return }
      catch { }
      recovery = record
      fail(error, generation: session.generation)
      if let action { log.record(action, (error as? HermesClientError) == .updateRequired ? .unsupported : .failed) }
    }
    if currentSend == attempt { currentSend = nil }
  }

  private func clearTerminalRecovery(_ record: PendingSendRecord) {
    if recovery?.sendId == record.sendId { recovery = nil }
    checkAttempted = false
    cancelSendAgain()
    phase = .idle
    currentSend = nil
  }

  private func complete(_ result: SendResult, record original: PendingSendRecord) {
    var record = original
    record.recoveryState = .completed
    terminalCleanup[record.sendId] = record
    retryTerminalCleanup()
    threadId = record.threadId ?? threadId
    handoff = result.handoff ?? handoff
    let replyId = "local-\(record.sendId)-reply"
    if !result.failed, !messages.contains(where: { $0.id == replyId }) {
      messages.append(ChatMessage(id: replyId, role: .assistant, content: result.text, at: Date(), tools: result.tools))
    }
    recovery = nil
    checkAttempted = false
    cancelSendAgain()
    if result.failed {
      messages.removeAll { $0.id == record.localMessageId }
      unsent = record.text
      let reason = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
      phase = .failed(reason.isEmpty ? .failed : .replyFailed(reason))
    } else { phase = .idle }
  }

  private func retryTerminalCleanup() {
    for record in Array(terminalCleanup.values) where matches(record) {
      do {
        try store.save(record)
        try store.discard(sendId: record.sendId, contextId: record.contextId, revision: record.revision)
        terminalCleanup.removeValue(forKey: record.sendId)
      } catch { }
    }
  }

  private var recoveryOutcome: RecoveryActionLog.Outcome {
    if case .failed(let error) = phase {
      return error == .updateRequired ? .unsupported : error == .recoveryStorage ? .storageFailed : .failed
    }
    switch recovery?.recoveryState {
    case .pending: return .pending
    case .uncertain: return .uncertain
    case .notSent: return .notSent
    case .completed, .discarded, nil: return .completed
    }
  }

  private func matches(_ record: PendingSendRecord) -> Bool {
    session.usable && record.contextId == session.contextId && record.revision == session.revision
  }

  func stopWaiting() {
    guard case .waiting = phase else { return }
    currentSend = nil
    detached = true
    phase = .idle
  }

  var busy: Bool {
    switch phase {
    case .sending, .loading, .transcribing, .waiting: true
    case .idle, .failed: false
    }
  }

  func sendVoice(_ audio: Data, mimeType: String) async {
    guard session.usable, !busy else { return }
    let generation = session.generation
    unsentVoice = nil
    phase = .transcribing
    do {
      let text = try await client.transcribe(audio: audio, mimeType: mimeType)
      guard generation == session.generation else { return }
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { phase = .failed(.noSpeech); return }
      phase = .idle
      await send(text)
    } catch {
      guard generation == session.generation else { return }
      unsentVoice = audio
      fail(error, generation: generation)
    }
  }

  private func fail(_ error: Error, generation: Int) {
    guard generation == session.generation else { return }
    if let reason = error as? HermesClientError, reason == .updateRequired || reason == .unavailable { recoveryAvailable = false }
    if (error as? HermesClientError) == .signedOut { session.invalidate(); return }
    phase = .failed(error as? HermesClientError ?? ((error as? PendingSendStoreError) == .capacity ? .recoveryCapacity : .recoveryStorage))
  }

  private func clearPrivateState() {
    permitsOriginalTitle = false
    if let record = recovery { try? store.invalidate(contextId: record.contextId, revision: record.revision) }
    else if let context = session.contextId { try? store.invalidate(contextId: context, revision: session.revision) }
    currentSend = nil
    threadId = nil
    handoff = nil
    messages = []
    unsent = nil
    unsentVoice = nil
    recovery = nil
    terminalCleanup.removeAll()
    checkAttempted = false
    recoveryAvailable = false
    cancelSendAgain()
    phase = .failed(session.invalidationReason)
  }
}
