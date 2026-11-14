part of 'app_shell.dart';

extension _AppShellDetection on _AppShellState {
  Future<void> _detect() async {
    if (!_authorizedOwner) return;
    final detection = ++_detection;
    final bool? kanban;
    final bool? schedules;
    try {
      (kanban, schedules) = await (
        _plugins?.kanbanStatus() ?? Future<bool?>.value(false),
        _cron?.availability() ?? Future<bool?>.value(false),
      ).wait;
    } on Object {
      // Neither answered; links for a tab keep waiting for the next check.
      return;
    }
    if (!_authorizedOwner || detection != _detection) return;
    _kanbanKnown = kanban != null;
    _schedulesKnown = schedules != null;
    _applyDetection(kanban ?? false, schedules ?? false);
  }

  void _applyDetection(bool kanban, bool schedules) {
    if (kanban != _kanban || schedules != _schedules) {
      _rebuild(() {
        _kanban = kanban;
        _schedules = schedules;
        if (!kanban) _drop(_Destination.kanban);
        if (!schedules) _drop(_Destination.schedules);
      });
      // An answer that could not be had says nothing about the routes, and
      // the watcher forgets what it saw when they are gone.
      if (_schedulesKnown) _watcher?.available = schedules;
      _syncSchedules();
    }
    final pending = _pendingJob;
    if (_schedulesKnown && pending != null) {
      _pendingJob = null;
      _openJob(pending);
    }
    _releaseWaitingLink();
  }

  void _ensureSchedules() {
    final cron = _cron;
    if (cron == null || _schedulesController != null) return;
    _schedulesController = SchedulesController(
      repository: cron,
      profiles: _profiles,
      prefs: SharedPreferencesAsync(),
      changeSource: _gateway,
      auth: _auth,
      events:
          HermesRepositories.maybeOf(context)?.telemetry.events ??
          noopAppEventLogger,
    );
  }

  void _syncSchedules() {
    final inFront = _current == _Destination.schedules;
    _schedulesController?.active = inFront;
    _watcher?.schedulesInFront = inFront;
  }
}
