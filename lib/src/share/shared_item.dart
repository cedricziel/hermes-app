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
