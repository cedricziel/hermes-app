// Ratchets the style score S (`dart run tool/style_score.dart`): per rule and
// file the count may only fall. It reuses the CLI's scanner and allowlist, so
// the two cannot disagree. See .claude/skills/hill-climb-style/SKILL.md.
import '../../tool/style_score/allowlist.dart';
import '../../tool/style_score/measure.dart';
import '../../tool/style_score/scanner.dart';
import 'ratchet.dart';

({List<Finding> findings, int allowlisted, List<AllowEntry> unused})? _cache;

List<Finding> _findings() => (_cache ??= measureLib()).findings;

Map<String, int> _scan(String id) {
  final out = <String, int>{};
  for (final f in _findings()) {
    if (f.ruleId == id) out[f.path] = (out[f.path] ?? 0) + 1;
  }
  return out;
}

List<String> _locate(String id, String path) => [
  for (final f in _findings())
    if (f.ruleId == id && f.path == path) '$path:${f.line}: ${f.snippet}',
];

Rule _rule(String id, String message) => Rule(
  id: id,
  message: message,
  scan: () => _scan(id),
  locate: (path) => _locate(id, path),
);

const _fontMessage =
    'Use a TextTheme role (Theme.of(context).textTheme.*) instead of a '
    'literal fontSize';

void main() {
  ratchetTests([
    _rule(
      'style.color',
      'Use a ColorScheme role or HermesColors/HermesChatColors '
          '(lib/src/theme/hermes_theme.dart)',
    ),
    _rule(
      'style.spacing',
      'Use a value on the spacing scale (see the hill-climb-style skill); a '
          'spacing token is pending',
    ),
    _rule(
      'style.radius',
      'Use kHermesRadius (14) or the radius scale 6/10/14/20/28/pill',
    ),
    _rule('style.font.role', _fontMessage),
    _rule('style.font.offRole', _fontMessage),
    _rule(
      'style.elevation',
      'The theme draws no shadows; use a border or surface tone '
          '(hermesOverlayEdge / ColorScheme.surfaceContainer*)',
    ),
    _rule(
      'style.dialog',
      'Use showAppDialog / AdaptiveDialog '
          '(lib/src/widgets/dialog_presentation.dart) or showAdaptiveSheet '
          '(lib/src/widgets/adaptive_sheet.dart)',
    ),
    _rule(
      'style.adaptive',
      'Use the .adaptive constructor (Switch.adaptive, Slider.adaptive, '
          'Checkbox.adaptive, CircularProgressIndicator.adaptive)',
    ),
    _rule(
      'style.string',
      'Put the text in lib/l10n/arb/app_en.arb and app_de.arb and read it '
          'with context.l10n',
    ),
  ], namespace: 'style');
}
