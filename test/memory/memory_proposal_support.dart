import 'dart:async';

import 'package:hermes_app/src/chat/slash_command.dart';

import '../support/fake_chat_transport.dart';

/// Answers each slash command from a script: a `String` is its output, an
/// `Exception` or `Error` is thrown, a `Completer<String>` is awaited. A
/// command without an entry answers "Done".
class ScriptedSlashTransport extends FakeChatTransport {
  final script = <String, Object>{};

  /// Every command, in the order it was asked, with the thread and profile.
  final asked = <(String?, String?, String)>[];

  @override
  Future<SlashCommandResult> runSlashCommand({
    String? threadId,
    String? profile,
    required String command,
  }) async {
    asked.add((threadId, profile, command));
    slashRuns.add(command);
    var answer = script[command] ?? 'Done';
    if (answer is Exception) throw answer;
    if (answer is Error) throw answer;
    if (answer is Completer<String>) answer = await answer.future;
    return SlashCommandResult(
      threadId: 'stored-${asked.length}',
      output: answer as String,
    );
  }
}
