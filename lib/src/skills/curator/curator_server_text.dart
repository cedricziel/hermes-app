import 'package:characters/characters.dart';

import '../../files/widgets/safe_path_text.dart';

/// The most characters of Hermes' own text the curator section shows.
const kCuratorServerTextLimit = 200;

/// [raw], a text of Hermes (a refused pause, a failed spawn, the last line of
/// a failed pass), made fit for one line on screen, or null when nothing
/// readable is left. Runs of white space (line breaks and tabs included)
/// become one space, then [safePathText] draws control and bidi characters as
/// `<U+XXXX>` and a lone surrogate as U+FFFD, as the output lines are, and at
/// most [limit] characters stay, cut at a character boundary with an
/// ellipsis. A cut never leaves half of a `<U+XXXX>` placeholder.
///
/// Screen state only: the result is never logged, traced or stored.
String? curatorServerText(String? raw, {int limit = kCuratorServerTextLimit}) {
  if (raw == null) return null;
  final safe = safePathText(raw.replaceAll(_space, ' ').trim());
  if (safe.isEmpty) return null;
  final chars = safe.characters;
  if (chars.length <= limit) return safe;
  final cut = chars.take(limit - 1).toString().replaceFirst(_partial, '');
  return '${cut.trimRight()}…';
}

// Only the white space that would break the line: other controls are left
// for safePathText to draw.
final _space = RegExp(r'[ \t\r\n  ]+');

// A placeholder cut in half at the end: `<`, `<U`, `<U+`, `<U+20`.
final _partial = RegExp(r'<(U(\+[0-9A-F]*)?)?$');
