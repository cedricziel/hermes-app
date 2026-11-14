/// How the Files page shows a file, decided by its name alone so nothing has
/// to be requested first.
enum FilePreviewKind {
  text,
  code,
  markdown,
  image,
  pdf,
  other;

  /// A fixed name for telemetry.
  String get slug => name;

  /// Whether the file is read with `read-text` first.
  bool get readsText => this == text || this == code || this == markdown;
}

const _markdown = {'md', 'markdown'};
const _images = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

/// The extensions of Hermes' language map. HTML and SVG are here on purpose:
/// they are shown as source text and never rendered.
const _code = {
  'py',
  'js',
  'mjs',
  'cjs',
  'ts',
  'tsx',
  'jsx',
  'json',
  'jsonl',
  'yaml',
  'yml', //
  'toml', 'sh', 'bash', 'zsh', 'fish', 'xml', 'html', 'htm', 'svg', 'css', //
  'scss', 'sql', 'rs', 'go', 'java', 'kt', 'swift', 'c', 'h', 'cc', 'cpp', //
  'hpp', 'rb', 'php', 'dart', 'lua', 'r', 'ps1', 'bat', 'gradle', 'tf', //
  'proto', 'vue',
};

const _text = {'txt', 'log', 'csv', 'tsv', 'ini', 'cfg', 'conf', 'rst'};

const _textNames = {
  'dockerfile',
  'makefile',
  'readme',
  'license',
  '.gitignore',
};

/// The kind of the file called [name].
FilePreviewKind previewKindFor(String name) {
  final lower = name.toLowerCase();
  if (_textNames.contains(lower)) return FilePreviewKind.text;
  final dot = lower.lastIndexOf('.');
  if (dot <= 0 || dot == lower.length - 1) return FilePreviewKind.other;
  final extension = lower.substring(dot + 1);
  if (_markdown.contains(extension)) return FilePreviewKind.markdown;
  if (_images.contains(extension)) return FilePreviewKind.image;
  if (extension == 'pdf') return FilePreviewKind.pdf;
  if (_code.contains(extension)) return FilePreviewKind.code;
  if (_text.contains(extension)) return FilePreviewKind.text;
  return FilePreviewKind.other;
}
