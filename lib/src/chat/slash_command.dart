/// A command advertised by the Hermes gateway for the current profile/session.
class SlashCommand {
  const SlashCommand(this.name, this.description);

  final String name;
  final String description;
}

/// The immediate result of a slash command. Some commands produce a prompt
/// that should be sent as the next agent turn.
class SlashCommandResult {
  const SlashCommandResult({
    required this.threadId,
    this.output = '',
    this.prompt,
    this.display,
    this.prefill,
  });

  final String threadId;
  final String output;
  final String? prompt;
  final String? display;
  final String? prefill;
}
