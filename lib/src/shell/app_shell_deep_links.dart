part of 'app_shell.dart';

extension _AppShellDeepLinks on _AppShellState {
  /// Opens the link that waited for a check, unless App Lock covers the app;
  /// the lock's own change brings it back here.
  void _releaseWaitingLink() {
    if (_appLock?.covered ?? false) return;
    if (_waitingLink case final waiting?) {
      _waitingLink = null;
      _openDeepLink(waiting, waited: true);
    }
  }

  /// Shows what a `hermes://` link names. Screens pushed over the page are
  /// closed first. Kanban and Schedules links wait for the server check that
  /// concerns them, and are ignored by a server that answered it lacks the
  /// tab. The breadcrumbs hold the kind and flags only, never the link.
  void _openDeepLink(PendingDeepLink link, {required bool waited}) {
    _beginExternalNavigation();
    final known = switch (link.target) {
      OpenKanban() => _kanbanKnown,
      OpenSchedules() => _schedulesKnown,
      _ => true,
    };
    final offered = switch (link.target) {
      OpenKanban() => _kanban,
      OpenSchedules() => _schedules,
      _ => true,
    };
    if (!known || !offered) {
      _externalNavigation.cancel();
      _applyDeepLink(link, waited: waited);
      return;
    }
    _waitingLink = null;
    _externalNavigation.request((guarded) {
      if (!mounted) return;
      if (_appLock?.covered ?? false) {
        _waitingLink = link;
        return;
      }
      _applyDeepLink(link, waited: waited || guarded);
    });
  }

  void _applyDeepLink(PendingDeepLink link, {required bool waited}) {
    _waitingLink = null;
    final target = link.target;
    void opened() => _breadcrumbs('deeplink.opened', {
      'kind': target.kind,
      'cold': link.cold,
      'waited': waited,
    });
    bool available({required bool known, required bool offered}) {
      if (!known) {
        _waitingLink = link;
        return false;
      }
      if (!offered) {
        _breadcrumbs('deeplink.ignored', {'reason': 'unavailable'});
        return false;
      }
      return true;
    }

    switch (target) {
      case OpenChat(:final profile, :final threadId, :final prompt):
        opened();
        _openRequests.request(
          NotificationTarget(threadId: threadId, profile: profile),
          prompt: prompt,
          fromLink: true,
        );
        _showChat();
      case NewChat(:final profile, :final dictate, :final prompt):
        opened();
        _openRequests.requestNew(
          profile: profile,
          prompt: prompt,
          dictate: dictate,
        );
        _showChat();
      case OpenRequests():
        opened();
        _openRequests.requestOldestPending();
        _showChat();
      case OpenKanban():
        if (!available(known: _kanbanKnown, offered: _kanban)) return;
        opened();
        Navigator.of(context).popUntil((route) => route.isFirst);
        _select(_Destination.kanban);
      case OpenSchedules(:final profile, :final jobId):
        if (!available(known: _schedulesKnown, offered: _schedules)) return;
        opened();
        if (jobId != null) {
          _openJob(NotificationTarget.job(jobId: jobId, profile: profile));
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
          _select(_Destination.schedules);
        }
    }
  }

  void _openRun(CronRun run, CronJob job) {
    _queueExternalNavigation(() {
      _openRequests.request(
        NotificationTarget(
          threadId: run.sessionId,
          profile: run.profile ?? job.profile,
        ),
      );
      _showChat();
    });
  }
}
