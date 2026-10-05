import 'chat_models.dart';

/// The sections a Mac sidebar sorts its threads into.
enum ThreadSectionKind {
  pinned('Pinned'),
  today('Today'),
  previous7Days('Previous 7 days'),
  previous30Days('Previous 30 days'),
  older('Older');

  const ThreadSectionKind(this.label);

  final String label;
}

typedef ThreadSection = ({ThreadSectionKind kind, List<ChatThread> threads});

/// [threads] split by when they were last active, pinned ones first, each
/// section in the order given and empty sections left out.
List<ThreadSection> groupThreads(
  Iterable<ChatThread> threads, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final weekAgo = today.subtract(const Duration(days: 7));
  final monthAgo = today.subtract(const Duration(days: 30));
  final byKind = <ThreadSectionKind, List<ChatThread>>{};
  for (final thread in threads) {
    final at = thread.updatedAt;
    final kind = thread.pinned
        ? ThreadSectionKind.pinned
        : !at.isBefore(today)
        ? ThreadSectionKind.today
        : !at.isBefore(weekAgo)
        ? ThreadSectionKind.previous7Days
        : !at.isBefore(monthAgo)
        ? ThreadSectionKind.previous30Days
        : ThreadSectionKind.older;
    (byKind[kind] ??= []).add(thread);
  }
  return [
    for (final kind in ThreadSectionKind.values)
      if (byKind[kind] case final threads?) (kind: kind, threads: threads),
  ];
}

String? sessionFolderPath(Map<String, dynamic> row) {
  for (final key in ['git_repo_root', 'cwd']) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) continue;
    final path = value.trim();
    if (RegExp(r'^[A-Za-z]:[/\\]$').hasMatch(path)) return path;
    final clean = path.replaceFirst(RegExp(r'[/\\]+$'), '');
    return clean.isEmpty ? path : clean;
  }
  return null;
}

typedef FolderThreadSection = ({
  String id,
  String label,
  List<ChatThread> threads,
});

List<FolderThreadSection> groupThreadsByFolder(Iterable<ChatThread> threads) {
  final pinned = <ChatThread>[];
  final unassigned = <ChatThread>[];
  final folders = <String, List<ChatThread>>{};
  for (final thread in threads) {
    if (thread.pinned) {
      pinned.add(thread);
    } else if (thread.folderPath case final String path when path.isNotEmpty) {
      (folders[path] ??= []).add(thread);
    } else {
      unassigned.add(thread);
    }
  }
  String basename(String path) =>
      path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).lastOrNull ??
      path;
  final names = <String, int>{};
  for (final path in folders.keys) {
    names.update(basename(path), (n) => n + 1, ifAbsent: () => 1);
  }
  return [
    if (pinned.isNotEmpty) (id: 'pinned', label: 'Pinned', threads: pinned),
    for (final entry in folders.entries)
      (
        id: 'folder:${entry.key}',
        label: names[basename(entry.key)]! > 1
            ? entry.key
            : basename(entry.key),
        threads: entry.value,
      ),
    if (unassigned.isNotEmpty)
      (id: 'no-folder', label: 'No folder', threads: unassigned),
  ];
}
