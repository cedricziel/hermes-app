import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../files_preview_kind.dart';

/// The picture and the word a file is shown with, decided by its name alone.
enum FileGlyph {
  folder,
  text,
  code,
  image,
  pdf,
  archive,
  generic;

  /// The icon of this kind. A folder is the filled one.
  AppIconSet get icon => switch (this) {
    folder => const AppIconSet(Icons.folder, CupertinoIcons.folder_fill),
    text => const AppIconSet(
      Icons.description_outlined,
      CupertinoIcons.doc_text,
    ),
    code => const AppIconSet(
      Icons.code,
      CupertinoIcons.chevron_left_slash_chevron_right,
    ),
    image => AppIcons.image,
    pdf => const AppIconSet(
      Icons.picture_as_pdf_outlined,
      CupertinoIcons.doc_richtext,
    ),
    archive => AppIcons.archive,
    generic => AppIcons.file,
  };
}

const _archives = {'zip', 'tar', 'gz', 'tgz', 'bz2', 'xz', '7z', 'rar', 'zst'};

String _extension(String name) {
  final lower = name.toLowerCase();
  final dot = lower.lastIndexOf('.');
  return dot <= 0 || dot == lower.length - 1 ? '' : lower.substring(dot + 1);
}

/// The glyph of the file called [name]; folders are [FileGlyph.folder] and
/// never come through here.
FileGlyph fileGlyphForName(String name) {
  if (_archives.contains(_extension(name))) return FileGlyph.archive;
  return switch (previewKindFor(name)) {
    FilePreviewKind.text || FilePreviewKind.markdown => FileGlyph.text,
    FilePreviewKind.code => FileGlyph.code,
    FilePreviewKind.image => FileGlyph.image,
    FilePreviewKind.pdf => FileGlyph.pdf,
    FilePreviewKind.other => FileGlyph.generic,
  };
}

/// Type words that are names, the same in every language.
const _named = {
  'py': 'Python',
  'js': 'JavaScript',
  'mjs': 'JavaScript',
  'cjs': 'JavaScript',
  'ts': 'TypeScript',
  'tsx': 'TypeScript',
  'jsx': 'JavaScript',
  'json': 'JSON',
  'jsonl': 'JSON',
  'yaml': 'YAML',
  'yml': 'YAML',
  'toml': 'TOML',
  'html': 'HTML',
  'htm': 'HTML',
  'css': 'CSS',
  'sql': 'SQL',
  'md': 'Markdown',
  'markdown': 'Markdown',
  'csv': 'CSV',
  'tsv': 'TSV',
  'svg': 'SVG',
  'xml': 'XML',
  'dart': 'Dart',
  'go': 'Go',
  'rs': 'Rust',
  'rb': 'Ruby',
  'php': 'PHP',
  'swift': 'Swift',
  'kt': 'Kotlin',
  'java': 'Java',
  'sh': 'Shell',
};

const _databases = {'db', 'sqlite', 'sqlite3'};

/// The type word of the file called [name] for the line under its name:
/// "Python", "Plain text", "PDF document", "File" for a file with no better
/// name.
String fileTypeLabel(AppLocalizations l10n, String name) {
  final extension = _extension(name);
  final named = _named[extension];
  if (named != null) return named;
  if (extension == 'zip') return l10n.filesTypeZip;
  if (extension == 'log') return l10n.filesTypeLog;
  if (_databases.contains(extension)) return l10n.filesTypeDatabase;
  return switch (fileGlyphForName(name)) {
    FileGlyph.archive => l10n.filesTypeArchive,
    FileGlyph.text => l10n.filesTypeText,
    FileGlyph.code => l10n.filesTypeCode,
    FileGlyph.image => l10n.filesTypeImage,
    FileGlyph.pdf => l10n.filesTypePdf,
    FileGlyph.generic || FileGlyph.folder => l10n.filesTypeFile,
  };
}
