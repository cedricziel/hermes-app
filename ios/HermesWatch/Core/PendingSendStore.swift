import Foundation

enum SendRecoveryState: String, Codable, Equatable {
  case pending, uncertain, notSent = "not_sent", completed, discarded
}

struct PendingSendRecord: Codable, Equatable {
  let sendId: String
  let contextId: String
  let revision: Int
  let profile: String?
  var threadId: String?
  var originalThreadId: String? = nil
  let text: String
  let localMessageId: String
  let createdAt: Date
  var recoveryState: SendRecoveryState
}

protocol PendingSendStore {
  func records(contextId: String, revision: Int) throws -> [PendingSendRecord]
  func save(_ record: PendingSendRecord) throws
  func discard(sendId: String, contextId: String, revision: Int) throws
  func invalidate(contextId: String, revision: Int) throws
}

enum PendingSendStoreError: Error, Equatable { case capacity, invalidated, identityChanged }

final class FilePendingSendStore: PendingSendStore {
  let directory: URL
  private let capacity: Int
  private let write: (Data, URL) throws -> Void
  private let remove: (URL) throws -> Void
  private var invalidated = Set<Scope>()
  private struct Scope: Codable, Hashable { let contextId: String; let revision: Int }
  private struct TerminalIdentity: Codable, Hashable { let sendId: String; let contextId: String; let revision: Int }
  private var recordsFile: URL { directory.appendingPathComponent("pending.json") }
  private var terminalFile: URL { directory.appendingPathComponent("terminal.json") }
  private var tombstone: URL { directory.appendingPathComponent("invalidated.json") }

  init(directory: URL, capacity: Int = 100,
    write: @escaping (Data, URL) throws -> Void = FilePendingSendStore.protectedWrite,
    remove: @escaping (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }) {
    self.directory = directory
    self.capacity = capacity
    self.write = write
    self.remove = remove
  }

  static var standard: FilePendingSendStore {
    FilePendingSendStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("pending-sends", isDirectory: true))
  }

  func records(contextId: String, revision: Int) throws -> [PendingSendRecord] {
    let scope = Scope(contextId: contextId, revision: revision)
    guard !(try invalidations()).contains(scope) else { return [] }
    let terminal = try terminalIdentities()
    return try readRecords().filter { $0.contextId == contextId && $0.revision == revision && $0.recoveryState != .completed && $0.recoveryState != .discarded && !terminal.contains(identity($0)) }
  }

  func save(_ record: PendingSendRecord) throws {
    let scope = Scope(contextId: record.contextId, revision: record.revision)
    guard !(try invalidations()).contains(scope) else { throw PendingSendStoreError.invalidated }
    let key = identity(record)
    let terminal = record.recoveryState == .completed || record.recoveryState == .discarded
    let identities = try terminalIdentities()
    guard terminal || !identities.contains(key) else { throw PendingSendStoreError.invalidated }
    let blocked = try invalidations()
    var records = try readRecords().filter {
      !blocked.contains(Scope(contextId: $0.contextId, revision: $0.revision))
        && (!identities.contains(identity($0)) || (terminal && identity($0) == key))
    }
    if let index = records.firstIndex(where: { $0.sendId == record.sendId }) {
      let old = records[index]
      guard old.contextId == record.contextId, old.revision == record.revision, old.createdAt == record.createdAt,
        old.text == record.text, old.profile == record.profile, old.localMessageId == record.localMessageId,
        old.originalThreadId == record.originalThreadId
      else { throw PendingSendStoreError.identityChanged }
      guard old.recoveryState != .completed && old.recoveryState != .discarded || old.recoveryState == record.recoveryState
      else { throw PendingSendStoreError.invalidated }
      records[index] = record
    } else {
      if identities.contains(key) { return }
      guard terminal || records.filter({ $0.contextId == record.contextId && $0.recoveryState != .completed && $0.recoveryState != .discarded }).count < capacity
      else { throw PendingSendStoreError.capacity }
      records.append(record)
    }
    if terminal { try persist(identities.union([key]), to: terminalFile) }
    try persist(records, to: recordsFile)
  }

  func discard(sendId: String, contextId: String, revision: Int) throws {
    guard !(try invalidations()).contains(Scope(contextId: contextId, revision: revision)) else { throw PendingSendStoreError.invalidated }
    var terminal = try terminalIdentities()
    terminal.insert(TerminalIdentity(sendId: sendId, contextId: contextId, revision: revision))
    try persist(terminal, to: terminalFile)
    let records = try readRecords().filter { $0.sendId != sendId || $0.contextId != contextId || $0.revision != revision }
    try persist(records, to: recordsFile)
  }

  func invalidate(contextId: String, revision: Int) throws {
    let scope = Scope(contextId: contextId, revision: revision)
    invalidated.insert(scope)
    var scopes = try invalidations()
    scopes.insert(scope)
    try persist(scopes, to: tombstone)
    let terminal = try terminalIdentities().filter { $0.contextId != contextId || $0.revision != revision }
    try? persist(Set(terminal), to: terminalFile)
    if FileManager.default.fileExists(atPath: recordsFile.path) {
      let kept = try readRecords().filter { $0.contextId != contextId || $0.revision != revision }
      if kept.isEmpty { try? remove(recordsFile) }
      else { try? persist(kept, to: recordsFile) }
    }
  }

  func invalidateAll() throws {
    var scopes = Set(try readRecords().map { Scope(contextId: $0.contextId, revision: $0.revision) })
    scopes.formUnion(try terminalIdentities().map { Scope(contextId: $0.contextId, revision: $0.revision) })
    for scope in scopes { try invalidate(contextId: scope.contextId, revision: scope.revision) }
  }

  private func identity(_ record: PendingSendRecord) -> TerminalIdentity {
    TerminalIdentity(sendId: record.sendId, contextId: record.contextId, revision: record.revision)
  }

  private func terminalIdentities() throws -> Set<TerminalIdentity> {
    guard FileManager.default.fileExists(atPath: terminalFile.path) else { return [] }
    return try JSONDecoder().decode(Set<TerminalIdentity>.self, from: Data(contentsOf: terminalFile))
  }

  private func invalidations() throws -> Set<Scope> {
    guard FileManager.default.fileExists(atPath: tombstone.path) else { return invalidated }
    return invalidated.union(try JSONDecoder().decode(Set<Scope>.self, from: Data(contentsOf: tombstone)))
  }

  private func readRecords() throws -> [PendingSendRecord] {
    guard FileManager.default.fileExists(atPath: recordsFile.path) else { return [] }
    return try JSONDecoder().decode([PendingSendRecord].self, from: Data(contentsOf: recordsFile))
  }

  private func persist<T: Encodable>(_ value: T, to file: URL) throws {
    try Self.prepareDirectory(file.deletingLastPathComponent())
    try write(JSONEncoder().encode(value), file)
    var protected = file
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try protected.setResourceValues(values)
  }

  private static func prepareDirectory(_ directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var excluded = directory
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try excluded.setResourceValues(values)
  }

  static func protectedWrite(_ data: Data, _ file: URL) throws {
    #if os(watchOS)
      try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    #else
      try data.write(to: file, options: .atomic)
    #endif
  }
}
