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
  private(set) var showingSavedMessages = false
  private(set) var messagesFetchedAt: Date?
  private(set) var deliveryStates: [String: SendRecoveryState] = [:]
  private var deliveryEvidence: [String: ConversationPresentation.DeliveryEvidence] = [:]

  func deliveryLabel(messageId: String) -> String? {
    guard let state = deliveryStates[messageId] else { return nil }
    return ConversationPresentation.deliveryLabel(state, evidence: deliveryEvidence[messageId] ?? .unknown)
  }
  private(set) var successfulReply = false
  private(set) var completedReplyId: String?
  private(set) var pendingRequestWaiting = false
  private(set) var phase = Phase.idle {
    didSet { voiceOwnsPhase = false }
  }
  private var voiceOwnsPhase = false
  private(set) var unsent: String?
  private var unsentMessageId: String?
  private(set) var voice = VoiceDraft()
  var unsentVoice: Data? { voice.audio }
  var voiceText: String {
    get { voice.text }
    set { voice.text = newValue }
  }
  private var voiceTask: Task<Void, Never>?
  private var voiceTaskId: UUID?
  private var voiceGeneration = 0
  private(set) var recovery: PendingSendRecord?
  private(set) var checkAttempted = false
  private(set) var resendConfirmation = false
  private(set) var recoveryAvailable = false
  private var replacementText: String?
  private var detached = false
  private var conversationGeneration = 0
  private var terminalCleanup: [String: PendingSendRecord] = [:]
  private var currentSend: UUID?
  private let session: WatchSessionState
  private var cleanupId: UUID?
  let requests: RequestActionsModel
  private let client: HermesClient
  private let store: PendingSendStore
  private let log: RecoveryActionLog
  private let onFreshMessagesLoaded: (() -> Void)?
  static let waitingLimit: TimeInterval = 20 * 60

  init(client: HermesClient, threadId: String?, handoff: HandoffTarget? = nil,
    session: WatchSessionState? = nil, store: PendingSendStore? = nil,
    log: RecoveryActionLog = RecoveryActionLog(), onFreshMessagesLoaded: (() -> Void)? = nil) {
    self.client = client
    self.threadId = threadId
    self.handoff = threadId == nil ? nil : handoff
    self.store = store ?? client.recoveryStore
    self.log = log
    self.onFreshMessagesLoaded = onFreshMessagesLoaded
    if threadId != nil { phase = .loading }
    let requestSession = session ?? client.sessionState ?? WatchSessionState()
    self.session = requestSession
    self.requests = RequestActionsModel(client: client, session: requestSession, access: .shared)
    cleanupId = self.session.register { [weak self] in self?.clearPrivateState() }
  }

  func load() async {
    requests.attach()
    guard session.usable else { return }
    let conversation = conversationGeneration
    let generation = session.generation
    phase = .loading
    if let threadId, messages.isEmpty, let saved = client.savedMessages(threadId: threadId) {
      messages = saved
      messagesFetchedAt = client.savedMessagesFetchedAt(threadId: threadId)
      showingSavedMessages = true
    }
    do {
      retryTerminalCleanup()
      try restore()
      try await client.prepareRecovery()
      recoveryAvailable = true
      guard conversation == conversationGeneration, generation == session.generation else { return }
      try restore()
      if let threadId {
        let loaded = try await client.messages(threadId: threadId)
        guard conversation == conversationGeneration, generation == session.generation else { return }
        messages = loaded
        messagesFetchedAt = client.savedMessagesFetchedAt(threadId: threadId)
        showingSavedMessages = false
        onFreshMessagesLoaded?()
        successfulReply = loaded.last?.role == .assistant
        appendRecoveryMessage()
      }
      phase = .idle
    } catch {
      guard conversation == conversationGeneration else { return }
      if generation == session.generation, !messages.isEmpty { showingSavedMessages = true }
      fail(error, generation: generation)
    }
  }

  private func restore() throws {
    guard let context = session.contextId else { return }
    if recovery == nil {
      recovery = try store.records(contextId: context, revision: session.revision)
        .first { terminalCleanup[$0.sendId] == nil && $0.threadId == threadId }
    }
    appendRecoveryMessage()
  }

  private func appendRecoveryMessage() {
    guard let recovery else { return }
    deliveryStates[recovery.localMessageId] = recovery.recoveryState
    guard !messages.contains(where: { $0.id == recovery.localMessageId }) else { return }
    messages.append(ChatMessage(id: recovery.localMessageId, role: .user, content: recovery.text, at: recovery.createdAt))
  }

  func send(_ raw: String) async {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard session.usable, !text.isEmpty, !busy, !pendingRequestWaiting else { return }
    if let recovery, (!detached || text == recovery.text), recovery.recoveryState != .notSent {
      guard canSendAgain else { return }
      replacementText = text
      resendConfirmation = true
      return
    }
    await begin(text)
  }

  private func begin(_ text: String) async {
    let conversation = conversationGeneration
    let generation = session.generation
    var journaled = false
    phase = .sending
    do {
      try await client.prepareRecovery()
      guard conversation == conversationGeneration, generation == session.generation, session.usable, let context = session.contextId else { return }
      recoveryAvailable = true
      retryTerminalCleanup()
      let old = detached ? nil : recovery
      let sendId = UUID().uuidString
      let record = PendingSendRecord(sendId: sendId, contextId: context, revision: session.revision,
        profile: threadId.flatMap { WatchThreadId.decode($0)?.profile }, threadId: threadId,
        text: text, localMessageId: "local-\(sendId)", createdAt: Date(), recoveryState: .pending)
      try store.save(record)
      if let old, old.recoveryState == .notSent {
        try store.discard(sendId: old.sendId, contextId: old.contextId, revision: old.revision)
        messages.removeAll { $0.id == old.localMessageId }
        deliveryStates.removeValue(forKey: old.localMessageId)
        deliveryEvidence.removeValue(forKey: old.localMessageId)
      }
      recovery = record
      journaled = true
      detached = false
      checkAttempted = false
      unsent = nil
      if let unsentMessageId {
        messages.removeAll { $0.id == unsentMessageId }
        deliveryStates.removeValue(forKey: unsentMessageId)
        deliveryEvidence.removeValue(forKey: unsentMessageId)
        self.unsentMessageId = nil
      }
      appendRecoveryMessage()
      await deliver(record, retry: false)
    } catch {
      guard conversation == conversationGeneration else { return }
      if !journaled, generation == session.generation, session.usable,
        (error as? HermesClientError) != .signedOut, (error as? HermesClientError) != .contextChanged {
        if let unsentMessageId { messages.removeAll { $0.id == unsentMessageId } }
        let id = unsentMessageId ?? "unsent-\(UUID().uuidString)"
        unsentMessageId = id
        unsent = text
        deliveryStates[id] = .notSent
        messages.append(ChatMessage(id: id, role: .user, content: text, at: Date()))
      }
      fail(error, generation: generation)
    }
  }

  func checkResult() async {
    guard !busy, let record = recovery, matches(record) else { return }
    checkAttempted = true
    let conversation = conversationGeneration
    let generation = session.generation
    do {
      try await client.prepareRecovery()
      guard conversation == conversationGeneration, generation == session.generation, matches(record) else { return }
      recoveryAvailable = true
      await deliver(record, retry: true, action: .checkResult)
    } catch {
      guard conversation == conversationGeneration else { return }
      fail(error, generation: generation)
      log.record(.checkResult, (error as? HermesClientError) == .updateRequired ? .unsupported : .failed)
    }
  }

  var canCompose: Bool { !busy && !pendingRequestWaiting && (recovery == nil || detached || recovery?.recoveryState == .notSent) }

  var canEditUnsent: Bool { !busy && (recovery?.recoveryState == .notSent || (recovery == nil && unsent != nil)) }

  func editUnsent() async -> String? {
    let generation = session.generation
    let conversation = conversationGeneration
    guard session.usable else { return nil }
    if !busy, recovery == nil, let unsent {
      await discardUnsent()
      guard session.usable, generation == session.generation, conversation == conversationGeneration else { return nil }
      return unsent
    }
    guard canEditUnsent, let record = recovery else { return nil }
    await discardUnsent()
    guard session.usable, generation == session.generation, conversation == conversationGeneration,
      recovery?.sendId != record.sendId else { return nil }
    return record.text
  }

  func discardUnsent() async {
    if !busy, recovery == nil, let unsentMessageId {
      messages.removeAll { $0.id == unsentMessageId }
      deliveryStates.removeValue(forKey: unsentMessageId)
      deliveryEvidence.removeValue(forKey: unsentMessageId)
      self.unsentMessageId = nil
      unsent = nil
      phase = .idle
      return
    }
    guard canEditUnsent, let record = recovery else { return }
    await forgetRecovery()
    guard recovery?.sendId != record.sendId else { return }
    messages.removeAll { $0.id == record.localMessageId }
    deliveryStates.removeValue(forKey: record.localMessageId)
    deliveryEvidence.removeValue(forKey: record.localMessageId)
  }

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
    let conversation = conversationGeneration
    do {
      try store.discard(sendId: record.sendId, contextId: record.contextId, revision: record.revision)
      recovery = nil
      checkAttempted = false
      cancelSendAgain()
      phase = .idle
      try? await client.forgetSend(sendId: record.sendId)
      if conversation == conversationGeneration, matches(record) { try restore() }
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
    var accepted = deliveryEvidence[record.localMessageId] == .accepted
    var notSent = false
    deliveryEvidence[record.localMessageId] = accepted ? .accepted : retry ? .unknown : .submitting
    func owned() -> Bool { currentSend == attempt && matches(record) }
    do {
      var result = try await client.send(threadId: record.threadId, text: record.text, sendId: record.sendId, retry: retry, createdAt: record.createdAt)
      guard owned() else { return }
      let deadline = Date().addingTimeInterval(Self.waitingLimit)
      while let waiting = result.waiting, result.recoveryState == nil {
        accepted = true
        record.recoveryState = .pending
        deliveryEvidence[record.localMessageId] = .accepted
        pendingRequestWaiting = waiting != .working
        deliveryStates[record.localMessageId] = .pending
        record.threadId = result.threadId ?? record.threadId
        try store.save(record)
        recovery = record
        threadId = record.threadId
        handoff = result.handoff ?? handoff
        phase = waiting == .working ? .sending : .waiting(waiting)
        if waiting != .working, result.inlineEligible, let requestId = result.requestId, let threadId = record.threadId {
          if requests.draft?.details?.requestId != requestId {
            await requests.load(threadId: threadId, requestId: requestId)
            guard owned() else { return }
          }
        } else { requests.clear() }
        guard Date() < deadline else { throw HermesClientError.failed }
        result = try await client.send(threadId: record.threadId, text: record.text, sendId: record.sendId, retry: true, createdAt: record.createdAt)
        guard owned() else { return }
      }
        requests.clear()
      record.threadId = result.threadId ?? record.threadId
      if let state = result.recoveryState {
        record.recoveryState = state
        accepted = state == .pending
        notSent = state == .notSent
        deliveryEvidence[record.localMessageId] = state == .pending ? .accepted : .unknown
        deliveryStates[record.localMessageId] = state
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
      else if notSent || (retry && original.recoveryState == .notSent) || (!retry && (error as? HermesClientError) == .notDelivered) { record.recoveryState = .notSent }
      else { record.recoveryState = .uncertain }
      do { try store.save(record) }
      catch PendingSendStoreError.invalidated { clearTerminalRecovery(record); return }
      catch { }
      recovery = record
      deliveryStates[record.localMessageId] = record.recoveryState
      deliveryEvidence[record.localMessageId] = accepted ? .accepted : .unknown
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
    if !messages.contains(where: { $0.id == replyId }) {
      let reply = result.failed && result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Hermes could not complete this request." : result.text
      messages.append(ChatMessage(id: replyId, role: .assistant, content: reply, at: Date(), tools: result.tools))
      completedReplyId = replyId
    }
    deliveryStates[record.localMessageId] = .completed
    successfulReply = !result.failed
    recovery = nil
    pendingRequestWaiting = false
    checkAttempted = false
    cancelSendAgain()
    if result.failed {
      unsent = nil
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

  func leaveConversation() {
    conversationGeneration += 1
    currentSend = nil
    requests.detach()
    detached = true
    phase = .idle
  }

  func stopWaiting() {
    requests.clear()
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

  func sendVoice(_ audio: Data, mimeType: String,
    reason: VoiceTerminationReason = .manual, fastSend: Bool = false) async {
    guard session.usable, !busy, voice.state == .idle else { return }
    let token = voice.start(audio: audio, mimeType: mimeType, reason: reason, fastSend: fastSend)
    await transcribeVoice(token)
  }

  func retryVoice() async {
    guard session.usable, !busy, let token = voice.retry() else { return }
    await transcribeVoice(token)
  }

  private func transcribeVoice(_ token: UUID) async {
    guard let audio = voice.audio else { return }
    let generation = session.generation
    let localGeneration = voiceGeneration
    let mimeType = voice.mimeType
    phase = .transcribing
    voiceOwnsPhase = true
    let task = Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        let text = try await client.transcribe(audio: audio, mimeType: mimeType)
        guard !Task.isCancelled, generation == session.generation,
          localGeneration == voiceGeneration, session.usable else { return }
        phase = .idle
        let automaticText = voice.complete(text, attempt: token, allowSend: canCompose)
        if let automaticText { await send(automaticText) }
      } catch {
        guard !Task.isCancelled, generation == session.generation,
          localGeneration == voiceGeneration else { return }
        voice.fail(attempt: token)
        fail(error, generation: generation)
        if voice.state == .failed, session.usable { voiceOwnsPhase = true }
      }
    }
    voiceTask = task
    voiceTaskId = token
    await task.value
    if voiceTaskId == token { voiceTask = nil; voiceTaskId = nil }
  }

  func sendVoiceDraft() async {
    guard session.usable, canCompose, let text = voice.takeText() else { return }
    await send(text)
  }

  func discardVoice() {
    voiceGeneration += 1
    voiceTask?.cancel()
    voiceTask = nil
    voiceTaskId = nil
    let resetPhase = voiceOwnsPhase && currentSend == nil
    voice.discard()
    if resetPhase { phase = .idle }
  }

  private func fail(_ error: Error, generation: Int) {
    guard generation == session.generation else { return }
    if let reason = error as? HermesClientError, reason == .updateRequired || reason == .unavailable { recoveryAvailable = false }
    if (error as? HermesClientError) == .signedOut { session.invalidate(); return }
    phase = .failed(error as? HermesClientError ?? ((error as? PendingSendStoreError) == .capacity ? .recoveryCapacity : .recoveryStorage))
  }

  private func clearPrivateState() {
    showingSavedMessages = false
    messagesFetchedAt = nil
    requests.clear()
    permitsOriginalTitle = false
    conversationGeneration += 1
    if let record = recovery { try? store.invalidate(contextId: record.contextId, revision: record.revision) }
    else if let context = session.contextId { try? store.invalidate(contextId: context, revision: session.revision) }
    currentSend = nil
    threadId = nil
    handoff = nil
    messages = []
    deliveryStates = [:]
    deliveryEvidence = [:]
    successfulReply = false
    completedReplyId = nil
    pendingRequestWaiting = false
    unsent = nil
    unsentMessageId = nil
    discardVoice()
    recovery = nil
    terminalCleanup.removeAll()
    checkAttempted = false
    recoveryAvailable = false
    cancelSendAgain()
    phase = .failed(session.invalidationReason)
  }
}
