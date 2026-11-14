import 'dart:async';

import '../api/hermes_repositories.dart';
import '../schedules/schedule_models.dart';
import 'chat_hints.dart';
import 'surface_snapshot.dart';

/// A built snapshot and the sources it could not read: [SourceFailures]
/// names them, and `sourcesFailed` counts every failed read (one per profile
/// whose chats failed).
typedef SnapshotBuild = ({
  SurfaceSnapshot snapshot,
  int sourcesFailed,
  SourceFailures failures,
});

/// Which sources of a build failed, by slug (`profiles`, `chats`, `kanban`,
/// `schedules`), split by why: [errored] threw or answered with an error,
/// [timedOut] was still running when the build's budget ran out. A budget
/// cut short is expected when the app goes to the background (the pause
/// build has 800 ms before iOS suspends it), so only [errored] makes a build
/// fail; a timed-out source just keeps its previous section.
class SourceFailures {
  const SourceFailures({this.errored = const {}, this.timedOut = const {}});

  final Set<String> errored;
  final Set<String> timedOut;

  bool get isEmpty => errored.isEmpty && timedOut.isEmpty;

  /// `ok`, `partial` (only time-outs) or `error`: the span's `outcome`.
  String get outcome => errored.isNotEmpty
      ? 'error'
      : timedOut.isNotEmpty
      ? 'partial'
      : 'ok';

  /// The span attributes that name the failed sources: sorted,
  /// comma-separated slugs, left out when there are none.
  Map<String, Object> get attributes => {
    'outcome': outcome,
    if (errored.isNotEmpty) 'sources_errored': _join(errored),
    if (timedOut.isNotEmpty) 'sources_timed_out': _join(timedOut),
  };

  static String _join(Set<String> slugs) => (slugs.toList()..sort()).join(',');
}

/// What a job without a name of its own is called: its prompt is never used,
/// since the snapshot must not carry what the user asked for.
const kUnnamedJobLabel = 'Scheduled task';

/// How one source answered: [value] when [ok], nothing when it failed or
/// [timedOut].
class _Read<T> {
  const _Read.ok(this.value) : ok = true, timedOut = false;
  const _Read.failed() : ok = false, timedOut = false, value = null;
  const _Read.timedOut() : ok = false, timedOut = true, value = null;

  final bool ok;
  final bool timedOut;
  final T? value;
}

/// Reads what the [SurfaceSnapshot] holds. Each source on its own: one that
/// fails or exhausts the shared [timeout] keeps its section from the previous
/// snapshot, like the welcome view's starter prompts do.
class SurfaceSnapshotBuilder {
  SurfaceSnapshotBuilder(
    this._repositories, {
    this.timeout = const Duration(milliseconds: 1500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final HermesRepositories _repositories;
  final Duration timeout;
  final DateTime Function() _now;

  /// [signedIn] is the caller's to say, since repositories outlive a session.
  /// [hints] are what the chat screen knows of the open profile: they stand
  /// in for a request for its chats and its open requests. Sources are read
  /// from the server only with [refreshRemote]; without it everything but the
  /// hints comes from [previous]. [pending] is the open requests of every
  /// profile as someone just read them: it replaces whatever [previous] held,
  /// so a request another profile has since answered is dropped, and the
  /// hints then only name the chats. With [redact] chat titles, snippets and
  /// job names are left out. [budget] overrides the shared remote-read timeout.
  Future<SnapshotBuild> build({
    required bool signedIn,
    SurfaceSnapshot? previous,
    ChatHints? hints,
    List<PendingRequest>? pending,
    bool refreshRemote = false,
    bool redact = false,
    Duration? budget,
  }) async {
    final openProfile = hints?.profile ?? previous?.profile ?? kDefaultProfile;
    final now = _now();
    var profiles = previous?.profiles ?? const <String>[];
    final kept = previous?.recentChats ?? const <RecentChat>[];
    var chats = kept;
    var kanban = previous?.kanban;
    var schedules = previous?.schedules;
    var failed = 0;
    final errored = <String>{};
    final timedOut = <String>{};
    void fail(String source, _Read<Object?> read) {
      failed++;
      (read.timedOut ? timedOut : errored).add(source);
    }

    if (refreshRemote) {
      final deadline = Completer<void>();
      var expired = false;
      final timer = Timer(budget ?? timeout, () {
        expired = true;
        deadline.complete();
      });
      Future<_Read<T>> read<T>(Future<T> Function() source) {
        if (expired) return Future.value(_Read<T>.timedOut());
        return Future.any([
          _read(source),
          deadline.future.then((_) => _Read<T>.timedOut()),
        ]);
      }

      try {
        Future<void> readChats() async {
          final names = await read(_profileNames);
          if (names.ok) {
            profiles = names.value!;
            // The hints stand in for a request for the open profile's chats.
            final toRead = [
              for (final name in profiles)
                if (hints == null || name != openProfile) name,
            ];
            final reads = await Future.wait([
              for (final name in toRead) read(() => _chats(name)),
            ]);
            chats = [
              for (final (index, read) in reads.indexed)
                ...read.ok
                    ? read.value!
                    : [...kept.where((c) => c.profile == toRead[index])],
            ];
            for (final read in reads) {
              if (!read.ok) fail('chats', read);
            }
          } else {
            fail('profiles', names);
          }
        }

        final (_, kanbanRead, schedulesRead) = await (
          readChats(),
          read(_kanban),
          read(() => _schedules(now, openProfile)),
        ).wait;
        if (kanbanRead.ok) {
          kanban = kanbanRead.value;
        } else {
          fail('kanban', kanbanRead);
        }
        if (schedulesRead.ok) {
          schedules = schedulesRead.value;
        } else {
          fail('schedules', schedulesRead);
        }
      } finally {
        timer.cancel();
        if (!deadline.isCompleted) deadline.complete();
      }
    }

    final seen = {
      for (final p in previous?.pending ?? const <PendingRequest>[])
        p.requestId: p.createdAt,
    };
    var open = [...?previous?.pending];
    if (pending != null) {
      open = [
        for (final p in pending) p.firstSeen(seen[p.requestId] ?? p.createdAt),
      ];
    }
    if (hints != null) {
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
      if (pending == null) {
        open = [
          ...open.where((p) => p.profile != openProfile),
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
    }

    final snapshot = SurfaceSnapshot(
      updatedAt: now,
      revision: previous?.revision ?? 0,
      signedIn: signedIn,
      profile: openProfile,
      profiles: profiles,
      recentChats: chats,
      pending: open,
      kanban: kanban,
      schedules: schedules,
    );
    return (
      snapshot: redact ? snapshot.redacted() : snapshot,
      sourcesFailed: failed,
      failures: SourceFailures(errored: errored, timedOut: timedOut),
    );
  }

  Future<_Read<T>> _read<T>(Future<T> Function() source) async {
    try {
      return _Read.ok(await source());
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
        // An unnamed session's title is the preview of its first prompt.
        title: thread.named ? thread.title : kUnnamedChatLabel,
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
