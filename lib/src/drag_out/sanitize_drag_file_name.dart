/// The longest file name a drag proposes, in characters.
const dragFileNameLimit = 120;

// Path separators, the colon Finder shows as a slash, NUL and the other C0
// control characters, and DEL.
final _unsafe = RegExp(r'[\x00-\x1f\x7f/\\:]');
final _leading = RegExp(r'^[.\s]+');

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
  var clean = name.replaceAll(_unsafe, '_').replaceFirst(_leading, '').trim();
  if (clean.isEmpty) clean = fallback;

  var ext = _extensionOf(clean);
  if (ext.isEmpty && extension.isNotEmpty) {
    ext = '.$extension';
    clean += ext;
  }
  if (clean.length <= dragFileNameLimit) return clean;
  // An extension this long is not one; cut the whole name.
  if (ext.length >= dragFileNameLimit ~/ 2) {
    return clean.substring(0, dragFileNameLimit);
  }
  final stem = clean.substring(0, clean.length - ext.length);
  return stem.substring(0, dragFileNameLimit - ext.length) + ext;
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 || dot == name.length - 1 ? '' : name.substring(dot);
}
