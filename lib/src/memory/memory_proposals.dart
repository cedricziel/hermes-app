import 'memory_usage.dart';

/// What a staged write changes.
enum ProposalKind {
  memory('memory', 'memory'),
  skill('skills', 'skill');

  const ProposalKind(this.command, this.slug);

  /// The slash command that lists and decides it.
  final String command;

  /// A fixed name for telemetry.
  final String slug;
}

/// The badge of a proposal. [change] is one whose action cannot be read.
enum ProposalAction {
  add('Add'),
  replace('Replace'),
  remove('Remove'),
  skill('Skill'),
  change('Change');

  const ProposalAction(this.label);
  final String label;
}

/// One staged write Hermes holds for the user's approval, read from the plain
/// text of `/memory pending` or `/skills pending`.
class MemoryProposal {
  const MemoryProposal({
    required this.id,
    required this.kind,
    required this.action,
    required this.background,
    required this.summary,
    this.target,
    this.skillName,
    this.replaced = const [],
    this.newText,
    this.mayBeShortened = false,
    this.warning,
  });

  final String id;
  final ProposalKind kind;
  final ProposalAction action;

  /// A background review staged it; otherwise a chat did.
  final bool background;

  /// What Hermes wrote for it, kept when nothing finer could be read.
  final String summary;

  /// The memory file a memory proposal writes to; null when unreadable.
  final MemoryTab? target;
  final String? skillName;

  /// The entries a replace or remove would overwrite, in full.
  final List<String> replaced;

  /// What would be written; null for a removal or when it cannot be told
  /// from [summary].
  final String? newText;

  /// [newText] may end before the proposal's text does: Hermes cuts it in
  /// this list, and approving applies all of it.
  final bool mayBeShortened;

  /// A line Hermes added that the reader should see, such as a replace with no
  /// entry pinned.
  final String? warning;

  /// The About you, Agent notes or skill name this writes to.
  String? get targetLabel => switch (kind) {
    ProposalKind.skill => skillName,
    ProposalKind.memory => target?.label,
  };
}

/// What a pending answer holds.
class ParsedProposals {
  const ParsedProposals(
    this.proposals, {
    this.unknownLines = const [],
    this.unreadable = false,
    this.raw = '',
  });

  static const empty = ParsedProposals([]);

  final List<MemoryProposal> proposals;

  /// Lines before the first proposal, or after the footer, that no rule
  /// covers.
  final List<String> unknownLines;

  /// The answer has text but no proposal and does not say that none wait.
  final bool unreadable;

  /// The answer as received, for an unreadable one.
  final String raw;
}

const _chatCut = 120;
const _backgroundCut = 200;

final _progress = RegExp(r'^\s*⏳');
final _header = RegExp(r'^Pending \S+ writes \(\d+\):\s*$');
final _footer = RegExp(r'^(Apply:|Review full diff:)');
final _item = RegExp(r'^\s{2}([0-9a-f]{8})(\s+\[auto\])?\s{2,}(.*)$');
final _detail = RegExp(r'^\s{6}(\w+?)s? entry: (.*)$');
final _background = RegExp(
  r'^background review consolidation \((\w+) on (\w+)\): (.*)$',
  dotAll: true,
);
final _chat = RegExp(
  r'^(\w+)\b[^:]*?\b(?:to|in|from) ([^:]+?): (.*)$',
  dotAll: true,
);
final _quoted = RegExp(r"'([^']+)'");
final _wholeEntry = RegExp(r'(?:^|\n)whole entry becomes: (.*)$', dotAll: true);
final _span = RegExp(
  r"(?:^|\n)span '.*' becomes: (.*?)(?: \(rest of the entry is kept\))?$",
  dotAll: true,
);
final _backgroundPatch = RegExp(
  r"^- patch span '.*' -> '(.*)'(?: \(rest of the entry is kept\))?$",
  dotAll: true,
);
final _backgroundLine = RegExp(r'^- (?:add|replace|remove): ?(.*)$');

/// Reads `/memory pending` leniently: a line it does not know is kept, never
/// an error.
ParsedProposals parseMemoryPending(String text) =>
    _parse(text, ProposalKind.memory);

/// Reads `/skills pending` the same way.
ParsedProposals parseSkillsPending(String text) =>
    _parse(text, ProposalKind.skill);

/// Drops the progress lines Hermes prints before a `/skills` answer.
String stripProgressLines(String text) =>
    text.split('\n').skipWhile(_progress.hasMatch).join('\n');

class _Draft {
  _Draft(this.id, this.background, String first) : summary = [first];
  final String id;
  final bool background;
  final List<String> summary;
  final replaced = <String>[];
  final verbs = <String>[];
  String? warning;
}

ParsedProposals _parse(String text, ProposalKind kind) {
  final answer = stripProgressLines(text).trim();
  if (answer.isEmpty || answer.startsWith('No pending')) {
    return ParsedProposals.empty;
  }
  final drafts = <_Draft>[];
  final unknown = <String>[];
  var afterFooter = false;
  var lastWasDetail = false;
  for (final line in answer.split('\n').map((l) => l.trimRight())) {
    if (line.isEmpty || _header.hasMatch(line)) continue;
    if (_footer.hasMatch(line)) {
      afterFooter = true;
      continue;
    }
    if (afterFooter) {
      unknown.add(line);
      continue;
    }
    if (_item.firstMatch(line) case final match?) {
      drafts.add(_Draft(match[1]!, match[2] != null, match[3]!));
      lastWasDetail = false;
      continue;
    }
    final current = drafts.lastOrNull;
    if (current == null) {
      unknown.add(line);
    } else if (_detail.firstMatch(line) case final match?) {
      current.verbs.add(match[1]!);
      current.replaced.add(match[2]!);
      lastWasDetail = true;
    } else if (line.startsWith('      ')) {
      current.warning = line.trim();
      lastWasDetail = false;
    } else if (lastWasDetail && current.replaced.isNotEmpty) {
      current.replaced.last = '${current.replaced.last}\n$line';
    } else {
      current.summary.add(line);
    }
  }
  if (drafts.isEmpty) {
    return ParsedProposals(
      const [],
      unknownLines: unknown,
      unreadable: true,
      raw: answer,
    );
  }
  return ParsedProposals([
    for (final draft in drafts) _proposal(draft, kind),
  ], unknownLines: unknown);
}

MemoryProposal _proposal(_Draft draft, ProposalKind kind) {
  final summary = draft.summary.join('\n');
  MemoryProposal build({
    ProposalAction action = ProposalAction.change,
    MemoryTab? target,
    String? skillName,
    String? newText,
    bool shortened = false,
  }) => MemoryProposal(
    id: draft.id,
    kind: kind,
    action: action,
    background: draft.background,
    summary: summary,
    target: target,
    skillName: skillName,
    replaced: draft.replaced,
    newText: newText,
    mayBeShortened: shortened,
    warning: draft.warning,
  );

  if (kind == ProposalKind.skill) {
    return build(
      action: ProposalAction.skill,
      skillName: _quoted.firstMatch(summary)?[1],
      newText: summary,
    );
  }
  if (_background.firstMatch(summary) case final match?) {
    final action = _actionOf(match[1]);
    final text = match[3]!;
    final newText = switch (match[1]) {
      'patch' => _backgroundPatch.firstMatch(text)?[1] ?? text,
      'add' || 'replace' => _backgroundLine.firstMatch(text)?[1] ?? text,
      _ => null,
    };
    return build(
      action: action ?? ProposalAction.change,
      target: _targetOf(match[2]!),
      newText: newText,
      shortened: summary.runes.length >= _backgroundCut || _ellipsis(newText),
    );
  }
  if (_chat.firstMatch(summary) case final match?) {
    final detail = match[3]!;
    final newText = switch (match[1]) {
      'add' => detail,
      'replace' => _wholeEntry.firstMatch(detail)?[1] ?? detail,
      'patch' => _span.firstMatch(detail)?[1] ?? detail,
      _ => null,
    };
    return build(
      action: _actionOf(match[1]) ?? ProposalAction.change,
      target: _targetOf(match[2]!),
      newText: newText,
      shortened: detail.runes.length >= _chatCut || _ellipsis(newText),
    );
  }
  return build(
    action: _actionOf(draft.verbs.firstOrNull) ?? ProposalAction.change,
  );
}

bool _ellipsis(String? text) => text != null && text.endsWith('…');

ProposalAction? _actionOf(String? word) => switch (word) {
  'add' => ProposalAction.add,
  'replace' || 'patch' => ProposalAction.replace,
  'remove' => ProposalAction.remove,
  _ => null,
};

MemoryTab? _targetOf(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('user') || lower.contains('profile')) {
    return MemoryTab.aboutYou;
  }
  if (lower.contains('memory') || lower.contains('notes')) {
    return MemoryTab.agentNotes;
  }
  return null;
}
