import '../chat/chat_transport.dart';

/// Where the commands about staged writes run, in one place so the inbox, the
/// waiting count and Approve all agree.
///
/// Each command gets a new gateway session of the profile and no thread id:
/// checked against Hermes d923a5eb, `session.create` followed by `slash.exec`
/// leaves no stored session, so no empty chat reaches the chat list.
class MemoryProposalSession {
  MemoryProposalSession(this._transport);

  final ChatTransport _transport;

  Future<String> run(String profile, String command) async =>
      (await _transport.runSlashCommand(
        profile: profile,
        command: command,
      )).output;
}
