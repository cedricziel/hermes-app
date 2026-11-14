/// How much a built-in toolset lets Hermes change, by name.
///
/// This table holds no text: the sentences, titles and questions are
/// localized where the screen draws them, keyed by [ToolsetRiskKind]. A name
/// that is not in it has no risk line and no question.
library;

enum ToolsetRiskLevel {
  /// The screen says what the toolset can do, but does not ask.
  explain,

  /// Switching it on asks first, every time.
  confirm,
}

/// What a toolset can do, for the sentence and note title the screen picks.
enum ToolsetRiskKind {
  runCommands,
  runPrograms,
  controlComputer,
  changeFiles,
  actOnWebPages,
  actOnItsOwn,
  manageDiscord,
}

class ToolsetRisk {
  const ToolsetRisk(this.level, this.kind);

  final ToolsetRiskLevel level;
  final ToolsetRiskKind kind;

  bool get asksBeforeSwitchingOn => level == ToolsetRiskLevel.confirm;
}

const kToolsetRisks = <String, ToolsetRisk>{
  'terminal': ToolsetRisk(
    ToolsetRiskLevel.confirm,
    ToolsetRiskKind.runCommands,
  ),
  'code_execution': ToolsetRisk(
    ToolsetRiskLevel.confirm,
    ToolsetRiskKind.runPrograms,
  ),
  'computer_use': ToolsetRisk(
    ToolsetRiskLevel.confirm,
    ToolsetRiskKind.controlComputer,
  ),
  'browser': ToolsetRisk(
    ToolsetRiskLevel.confirm,
    ToolsetRiskKind.actOnWebPages,
  ),
  'file': ToolsetRisk(ToolsetRiskLevel.explain, ToolsetRiskKind.changeFiles),
  'cronjob': ToolsetRisk(ToolsetRiskLevel.explain, ToolsetRiskKind.actOnItsOwn),
  'delegation': ToolsetRisk(
    ToolsetRiskLevel.explain,
    ToolsetRiskKind.actOnItsOwn,
  ),
  'discord_admin': ToolsetRisk(
    ToolsetRiskLevel.explain,
    ToolsetRiskKind.manageDiscord,
  ),
};

/// Built-in toolsets that carry no risk line on purpose. Together with
/// [kToolsetRisks] they are the names the app has decided about; a name the
/// server lists that is in neither has not been looked at.
const kNoRiskToolsets = <String>{
  'web',
  'image_gen',
  'video_gen',
  'tts',
  'stt',
  'todo',
  'session_search',
};

ToolsetRisk? toolsetRisk(String name) => kToolsetRisks[name];

/// A fixed telemetry label for a toolset: its name when the app knows it,
/// else `other`, so a plugin's toolset name never leaves the device.
String toolsetSlug(String name) =>
    kToolsetRisks.containsKey(name) || kNoRiskToolsets.contains(name)
    ? name
    : 'other';
