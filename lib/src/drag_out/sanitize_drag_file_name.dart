import 'package:characters/characters.dart';

/// The longest file name a drag proposes, in characters (grapheme clusters).
const dragFileNameLimit = 120;

// Path separators, the colon Finder shows as a slash, NUL and the other C0
// control characters, and DEL.
final _unsafe = RegExp(r'[\x00-\x1f\x7f/\\:]');
final _leading = RegExp(r'^[.\s]+');

// Characters that reorder or hide the text after them: the bidi embeddings,
// overrides and isolates, the left-to-right and right-to-left marks and the
// Arabic letter mark. `invoice<RLO>fdp.exe` would read `invoiceexe.pdf`.
final _bidi = RegExp(r'[\u202A-\u202E\u2066-\u2069\u200E\u200F\u061C]');

/// A file name that is safe to hand to another app: no path separators, no
/// colon, no control characters, no leading dots (a hidden file or `..`), at
/// most [dragFileNameLimit] characters with the extension kept, and
/// [fallback] when nothing is left.
///
/// [extension] (without the dot) is appended when the name has none, so a
/// chat titled `Plan` can become `Plan.md`.
String sanitizeDragFileName(
  String name, {
  String fallback = 'File',
  String extension = '',
}) {
  var clean = name
      .replaceAll(_bidi, '')
      .replaceAll(_unsafe, '_')
      .replaceFirst(_leading, '')
      .trim();
  if (clean.isEmpty) clean = fallback;

  var ext = _extensionOf(clean);
  if (ext.isEmpty && extension.isNotEmpty) {
    ext = '.$extension';
    clean += ext;
  }
  final characters = clean.characters;
  if (characters.length <= dragFileNameLimit) return clean;
  final extLength = ext.characters.length;
  // An extension this long is not one; cut the whole name.
  if (extLength >= dragFileNameLimit ~/ 2) {
    return characters.take(dragFileNameLimit).toString();
  }
  final stem = clean.substring(0, clean.length - ext.length).characters;
  return stem.take(dragFileNameLimit - extLength).toString() + ext;
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 || dot == name.length - 1 ? '' : name.substring(dot);
}
