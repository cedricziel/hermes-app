import 'dart:async';

import '../api/hermes_repositories.dart';
import '../schedules/schedule_models.dart';
import 'chat_hints.dart';
import 'surface_snapshot.dart';

/// A built snapshot and how many of its sources could not be read.
typedef SnapshotBuild = ({SurfaceSnapshot snapshot, int sourcesFailed});

/// What a job without a name of its own is called: its prompt is never used,
/// since the snapshot must not carry what the user asked for.
const kUnnamedJobLabel = 'Scheduled task';

/// How one source answered: [value] when [ok], nothing when it failed or
/// took too long.
class _Read<T> {
  const _Read.ok(this.value) : ok = true;
  const _Read.failed() : ok = false, value = null;

  final bool ok;
  final T? value;
}

/// Reads what the [SurfaceSnapshot] holds. Each source on its own: one that
/// fails or takes longer than [timeout] keeps its section from the previous
/// snapshot, like the welcome view's starter prompts do.
class SurfaceSnapshotBuilder {
  SurfaceSnapshotBuilder(
    this._repositories, {
    this.timeout = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final HermesRepositories _repositories;
  final Duration timeout;
  final DateTime Function() _now;

  /// [signedIn] is the caller's to say, since repositories outlive a session.
  /// [hints] are what the chat screen knows of the open profile: they stand
  /// in for a request for its chats and its open requests. Sources are read
  /// from the server only with [refreshRemote]; without it everything but the
  /// hints comes from [previous]. With [redact] chat titles, snippets and job
  /// names are left out.
  Future<SnapshotBuild> build({
    required bool signedIn,
    SurfaceSnapshot? previous,
    ChatHints? hints,
    bool refreshRemote = false,
    bool redact = false,
  }) async {
    final openProfile = hints?.profile ?? previous?.profile ?? kDefaultProfile;
    final now = _now();
    var profiles = previous?.profiles ?? const <String>[];
    final kept = previous?.recentChats ?? const <RecentChat>[];
    var chats = kept;
    var kanban = previous?.kanban;
    var schedules = previous?.schedules;
    var failed = 0;

    if (refreshRemote) {
      final (names, kanbanRead, schedulesRead) = await (
        _read(_profileNames),
        _read(_kanban),
        _read(() => _schedules(now, openProfile)),
      ).wait;
      if (names.ok) {
        profiles = names.value!;
        // The hints stand in for a request for the open profile's chats.
        final toRead = [
          for (final name in profiles)
            if (hints == null || name != openProfile) name,
        ];
        final reads = await Future.wait([
          for (final name in toRead) _read(() => _chats(name)),
        ]);
        chats = [
          for (final (index, read) in reads.indexed)
            ...read.ok
                ? read.value!
                : [...kept.where((c) => c.profile == toRead[index])],
        ];
        failed += reads.where((read) => !read.ok).length;
      } else {
        failed++;
      }
      if (kanbanRead.ok) {
        kanban = kanbanRead.value;
      } else {
        failed++;
      }
      if (schedulesRead.ok) {
        schedules = schedulesRead.value;
      } else {
        failed++;
      }
    }

    var pending = [...?previous?.pending];
    if (hints != null) {
      final seen = {for (final p in pending) p.requestId: p.createdAt};
      chats = [
        ...chats.where((c) => c.profile != openProfile),
        for (final thread in hints.threads)
          RecentChat(
            profile: openProfile,
            id: thread.id,
            title: thread.title,
            snippet: thread.snippet,
            updatedAt: thread.updatedAt,
          ),
      ];
      pending = [
        ...pending.where((p) => p.profile != openProfile),
        for (final request in hints.requests)
          PendingRequest(
            profile: openProfile,
            threadId: request.threadId,
            threadTitle: request.threadTitle,
            kind: request.kind,
            requestId: request.requestId,
            createdAt: seen[request.requestId] ?? request.seenAt,
          ),
      ];
    }

    final snapshot = SurfaceSnapshot(
      updatedAt: now,
      signedIn: signedIn,
      profile: openProfile,
      profiles: profiles,
      recentChats: chats,
      pending: pending,
      kanban: kanban,
      schedules: schedules,
    );
    return (
      snapshot: redact ? snapshot.redacted() : snapshot,
      sourcesFailed: failed,
    );
  }

  Future<_Read<T>> _read<T>(Future<T> Function() source) async {
    try {
      return _Read.ok(await source().timeout(timeout));
    } on Object {
      return const _Read.failed();
    }
  }

  Future<List<String>> _profileNames() async => [
    for (final profile in await _repositories.profiles.list()) profile.name,
  ];

  Future<List<RecentChat>> _chats(String profile) async => [
    for (final thread in await _repositories.chat.loadThreads(
      limit: kMaxRecentChats,
      profile: profile,
    ))
      RecentChat(
        profile: profile,
        id: thread.id,
        title: thread.title,
        updatedAt: thread.updatedAt,
      ),
  ];

  Future<KanbanSummary?> _kanban() async {
    if (!await _repositories.plugins.isKanbanEnabled()) return null;
    final columns = (await _repositories.kanban.loadBoard()).columns;
    int count(String status) => columns
        .where((c) => c.name == status)
        .fold(0, (sum, c) => sum + c.tasks.length);
    return KanbanSummary(blocked: count('blocked'), review: count('review'));
  }

  String _jobName(CronJob job) =>
      job.name.trim().isEmpty ? kUnnamedJobLabel : job.name.trim();

  Future<ScheduleSummary?> _schedules(DateTime now, String openProfile) async {
    if (!await _repositories.cron.isAvailable()) return null;
    final jobs = await _repositories.cron.listJobs(profile: 'all');
    CronJob? next;
    CronJob? lastFailed;
    for (final job in jobs) {
      final nextRunAt = job.nextRunAt;
      if (!job.isPaused &&
          job.state != CronJobState.completed &&
          nextRunAt != null &&
          nextRunAt.isAfter(now) &&
          (next == null || nextRunAt.isBefore(next.nextRunAt!))) {
        next = job;
      }
      final ranAt = job.lastRunAt;
      if (job.outcome == CronOutcome.failed &&
          ranAt != null &&
          (lastFailed == null || ranAt.isAfter(lastFailed.lastRunAt!))) {
        lastFailed = job;
      }
    }
    return ScheduleSummary(
      nextRunAt: next?.nextRunAt,
      nextJobName: next == null ? null : _jobName(next),
      lastFailed: lastFailed == null
          ? null
          : FailedJob(
              profile: lastFailed.profile ?? openProfile,
              jobId: lastFailed.id,
              name: _jobName(lastFailed),
              at: lastFailed.lastRunAt!,
            ),
    );
  }
}
