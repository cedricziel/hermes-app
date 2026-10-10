/// Something another app shared with Hermes through the OS share sheet.
sealed class SharedItem {
  const SharedItem();
}

/// Shared text, including web links (a URL arrives as its own string).
final class SharedText extends SharedItem {
  const SharedText(this.text);

  final String text;

  @override
  bool operator ==(Object other) => other is SharedText && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Text selected in another app and handed over by the macOS Services menu
/// ("Ask Hermes"). Unlike [SharedText] it starts a new chat, with the text
/// quoted in the composer. [truncated] says the native side cut it short.
final class SharedQuote extends SharedItem {
  const SharedQuote(this.text, {this.truncated = false});

  final String text;
  final bool truncated;

  /// The text as a Markdown block quote followed by an empty line, with a
  /// last line saying so when it was cut short.
  String get asBlockQuote {
    final lines = text
        .trimRight()
        .split(RegExp(r'\r\n|\r|\n'))
        .map((line) => line.isEmpty ? '>' : '> $line');
    return '${lines.join('\n')}${truncated ? '\n> [selection shortened]' : ''}'
        '\n\n';
  }

  @override
  bool operator ==(Object other) =>
      other is SharedQuote &&
      other.text == text &&
      other.truncated == truncated;

  @override
  int get hashCode => Object.hash(text, truncated);
}

/// A file (or image) copied into app-readable storage by the share
/// extension.
final class SharedFile extends SharedItem {
  const SharedFile({
    required this.path,
    required this.name,
    this.mimeType,
    this.isImage = false,
  });

  final String path;
  final String name;
  final String? mimeType;
  final bool isImage;

  @override
  bool operator ==(Object other) =>
      other is SharedFile &&
      other.path == path &&
      other.name == name &&
      other.mimeType == mimeType &&
      other.isImage == isImage;

  @override
  int get hashCode => Object.hash(path, name, mimeType, isImage);
}
