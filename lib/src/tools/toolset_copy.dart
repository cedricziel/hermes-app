/// The words the Tools screens use for built-in toolsets: one sentence and
/// one name for each, what a risk kind means, and the question asked before
/// a toolset is switched on. Only strings and pure functions live here; the
/// dialogs that show the questions are built where they are used.
///
/// The names below are the ones the risk table (`toolset_risk.dart`) uses,
/// plus `vision`, `clarify`, `context_engine`, `kanban`, `memory`, `skills`
/// and `discord`, which other parts of the app also use. Name unverified
/// against the server catalog: `video` and `video_analysis` (both read as
/// video analysis), `x_search` and `connections`. A name that is not here
/// shows the server's own label and description.
library;

import '../../l10n/l10n.dart';
import 'toolset_risk.dart';

/// The one-sentence description of a built-in toolset, or null for a name
/// the app has no sentence for, so the caller shows the server's own text.
String? toolsetSentence(AppLocalizations l10n, String name) => switch (name) {
  'web' => l10n.toolsSentenceWeb,
  'browser' => l10n.toolsSentenceBrowser,
  'terminal' => l10n.toolsSentenceTerminal,
  'file' => l10n.toolsSentenceFile,
  'code_execution' => l10n.toolsSentenceCodeExecution,
  'vision' => l10n.toolsSentenceVision,
  'video' || 'video_analysis' => l10n.toolsSentenceVideoAnalysis,
  'image_gen' => l10n.toolsSentenceImageGen,
  'video_gen' => l10n.toolsSentenceVideoGen,
  'x_search' => l10n.toolsSentenceXSearch,
  'tts' => l10n.toolsSentenceTts,
  'stt' => l10n.toolsSentenceStt,
  'skills' => l10n.toolsSentenceSkills,
  'todo' => l10n.toolsSentenceTodo,
  'kanban' => l10n.toolsSentenceKanban,
  'memory' => l10n.toolsSentenceMemory,
  'context_engine' => l10n.toolsSentenceContextEngine,
  'session_search' => l10n.toolsSentenceSessionSearch,
  'connections' => l10n.toolsSentenceConnections,
  'clarify' => l10n.toolsSentenceClarify,
  'delegation' => l10n.toolsSentenceDelegation,
  'cronjob' => l10n.toolsSentenceCronjob,
  'discord' => l10n.toolsSentenceDiscord,
  'discord_admin' => l10n.toolsSentenceDiscordAdmin,
  'computer_use' => l10n.toolsSentenceComputerUse,
  _ => null,
};

/// The display name of a built-in toolset; [fallback] (the server's label,
/// else the name itself) for any other.
String toolsetLabel(AppLocalizations l10n, String name, {String? fallback}) =>
    switch (name) {
      'web' => l10n.toolsLabelWeb,
      'browser' => l10n.toolsLabelBrowser,
      'terminal' => l10n.toolsLabelTerminal,
      'file' => l10n.toolsLabelFile,
      'code_execution' => l10n.toolsLabelCodeExecution,
      'vision' => l10n.toolsLabelVision,
      'video' || 'video_analysis' => l10n.toolsLabelVideoAnalysis,
      'image_gen' => l10n.toolsLabelImageGen,
      'video_gen' => l10n.toolsLabelVideoGen,
      'x_search' => l10n.toolsLabelXSearch,
      'tts' => l10n.toolsLabelTts,
      'stt' => l10n.toolsLabelStt,
      'skills' => l10n.toolsLabelSkills,
      'todo' => l10n.toolsLabelTodo,
      'kanban' => l10n.toolsLabelKanban,
      'memory' => l10n.toolsLabelMemory,
      'context_engine' => l10n.toolsLabelContextEngine,
      'session_search' => l10n.toolsLabelSessionSearch,
      'connections' => l10n.toolsLabelConnections,
      'clarify' => l10n.toolsLabelClarify,
      'delegation' => l10n.toolsLabelDelegation,
      'cronjob' => l10n.toolsLabelCronjob,
      'discord' => l10n.toolsLabelDiscord,
      'discord_admin' => l10n.toolsLabelDiscordAdmin,
      'computer_use' => l10n.toolsLabelComputerUse,
      _ => fallback ?? name,
    };

/// The title of a risk note.
String toolsetRiskTitle(AppLocalizations l10n, ToolsetRiskKind kind) =>
    switch (kind) {
      ToolsetRiskKind.runCommands ||
      ToolsetRiskKind.runPrograms ||
      ToolsetRiskKind.changeFiles => l10n.toolsRiskChangeThingsTitle,
      ToolsetRiskKind.controlComputer => l10n.toolsRiskControlComputerTitle,
      ToolsetRiskKind.actOnWebPages => l10n.toolsRiskActOnWebPagesTitle,
      ToolsetRiskKind.actOnItsOwn => l10n.toolsRiskActOnItsOwnTitle,
      ToolsetRiskKind.manageDiscord => l10n.toolsRiskManageDiscordTitle,
    };

/// The plain sentence of a risk note.
String toolsetRiskSentence(AppLocalizations l10n, ToolsetRiskKind kind) =>
    switch (kind) {
      ToolsetRiskKind.runCommands => l10n.toolsRiskRunCommandsSentence,
      ToolsetRiskKind.runPrograms => l10n.toolsRiskRunProgramsSentence,
      ToolsetRiskKind.changeFiles => l10n.toolsRiskChangeFilesSentence,
      ToolsetRiskKind.controlComputer => l10n.toolsRiskControlComputerSentence,
      ToolsetRiskKind.actOnWebPages => l10n.toolsRiskActOnWebPagesSentence,
      ToolsetRiskKind.actOnItsOwn => l10n.toolsRiskActOnItsOwnSentence,
      ToolsetRiskKind.manageDiscord => l10n.toolsRiskManageDiscordSentence,
    };

/// A question asked before a toolset is switched on.
class ToolsetQuestion {
  const ToolsetQuestion({required this.title, required this.body});

  final String title;
  final String body;
}

/// The question for a confirm-level toolset, or null when [name] has none
/// of its own (the caller then asks [toolsetInstallQuestion] if the toolset
/// can start an installer). The body is what the toolset can do, the profile
/// it applies to, and what switching it off does.
ToolsetQuestion? toolsetConfirmQuestion(
  AppLocalizations l10n,
  String name,
  String profile,
) {
  final (title, lead, extra, off) = switch (name) {
    'terminal' => (
      l10n.toolsConfirmTerminalTitle,
      l10n.toolsConfirmTerminalLead,
      null,
      l10n.toolsConfirmOffCommands,
    ),
    'code_execution' => (
      l10n.toolsConfirmCodeExecutionTitle,
      l10n.toolsConfirmCodeExecutionLead,
      null,
      l10n.toolsConfirmOffCommands,
    ),
    'browser' => (
      l10n.toolsConfirmBrowserTitle,
      l10n.toolsConfirmBrowserLead,
      null,
      l10n.toolsConfirmOffActions,
    ),
    'computer_use' => (
      l10n.toolsConfirmComputerUseTitle,
      l10n.toolsConfirmComputerUseLead,
      l10n.toolsConfirmComputerUseDriver,
      l10n.toolsConfirmOffActions,
    ),
    _ => (null, null, null, null),
  };
  if (title == null || lead == null || off == null) return null;
  return ToolsetQuestion(
    title: title,
    body: [lead, ?extra, l10n.toolsConfirmApplies(profile), off].join(' '),
  );
}

/// The question for a toolset outside the confirm level that may start an
/// installer when it is switched on.
ToolsetQuestion toolsetInstallQuestion(AppLocalizations l10n, String label) =>
    ToolsetQuestion(
      title: l10n.toolsConfirmInstallTitle,
      body: l10n.toolsConfirmInstallBody(label),
    );
