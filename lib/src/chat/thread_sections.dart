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
