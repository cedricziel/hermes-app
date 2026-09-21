import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'kanban_repository.dart';

/// The plugin's cap on an attachment (`KANBAN_ATTACHMENT_MAX_BYTES`, shared by
/// its dashboard, tools and CLI). Checked before reading a file so a huge one
/// is not loaded into memory just to be refused.
const kanbanAttachmentLimitBytes = 25 * 1024 * 1024;

/// A file the user chose to attach, read in full.
class KanbanPickedFile {
  const KanbanPickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// The device's file dialogs, behind an interface so tests need no platform.
abstract interface class KanbanFiles {
  /// Asks the user for a file; null when they cancel.
  Future<KanbanPickedFile?> pick();

  /// Asks the user where to save [bytes] as [name] and writes them there.
  /// False when they cancel.
  Future<bool> save(String name, Uint8List bytes);
}

class PlatformKanbanFiles implements KanbanFiles {
  const PlatformKanbanFiles();

  @override
  Future<KanbanPickedFile?> pick() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > kanbanAttachmentLimitBytes) {
      throw KanbanException(
        '${file.name} is over the ${kanbanAttachmentLimitBytes ~/ (1024 * 1024)} MB limit for attachments.',
      );
    }
    return KanbanPickedFile(
      name: file.name,
      bytes: await file.xFile.readAsBytes(),
    );
  }

  @override
  Future<bool> save(String name, Uint8List bytes) async =>
      await FilePicker.saveFile(fileName: name, bytes: bytes) != null;
}
