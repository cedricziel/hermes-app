part of 'app_shell.dart';

extension _AppShellNavigation on _AppShellState {
  /// Puts Chat in front. The chat asks for this when a notification tap or
  /// shared content lands there while another page is on screen. Screens
  /// pushed over that page (a task, board management, a job) are dismissed
  /// too, or the user would stay on them; so are pages pushed over Chat
  /// itself (Skills, Plugins), which would hide the new content.
  void _showChat() {
    DesktopNavigationHistoryScope.maybeOf(context)?.clear();
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (_current == _Destination.chat) return;
    _select(_Destination.chat, cancelHandoff: false);
  }

  /// Forgets a destination that went off, so it is not rebuilt, or reloaded,
  /// by coming back on.
  void _drop(_Destination destination) {
    _opened.remove(destination);
    if (_current == destination) {
      _current = _Destination.chat;
      _breadcrumbs('nav.destination', {'destination': 'chat', 'gone': true});
    }
    if (destination == _Destination.schedules) {
      final controller = _schedulesController;
      _schedulesController = null;
      // The page still listens until this frame is built.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller?.dispose(),
      );
    }
  }

  void _selectByUser(_Destination destination) {
    _shareEntryValid = destination == _Destination.chat;
    if (destination == _Destination.chat) {
      _rebuild(() => _shareEntry++);
    }
    _select(destination);
  }

  void _recoverShared(VoidCallback action, int entry) {
    if (!mounted || !_shareEntryValid || entry != _shareEntry) return;
    _queueExternalNavigation(action);
  }

  void _select(_Destination destination, {bool cancelHandoff = true}) {
    if (cancelHandoff) _maybeRead<HandoffController>()?.cancel();
    _sidebar.closeOverlay();
    if (_current == destination) return;
    DesktopNavigationHistoryScope.maybeOf(context)?.clear();
    _breadcrumbs('nav.destination', {'destination': destination.name});
    _rebuild(() {
      _current = destination;
      _opened.add(destination);
      if (destination == _Destination.schedules) _ensureSchedules();
    });
    _syncSchedules();
  }

  RootNavigationQueue get _externalNavigation =>
      _navigationQueue ??= RootNavigationQueue(
        navigator: Navigator.of(context),
        root: ModalRoute.of(context)!,
        history: DesktopNavigationHistoryScope.maybeOf(context),
        canNavigate: () => _authorizedOwner && !(_appLock?.covered ?? false),
      );

  void _queueExternalNavigation(VoidCallback action, [bool isLaunch = false]) {
    if (!mounted || (isLaunch && !_externalNavigation.canAcceptLaunch)) return;
    _beginExternalNavigation();
    _externalNavigation.request((_) {
      if (mounted) action();
    }, isLaunch: isLaunch);
  }

  int _beginExternalNavigation() {
    _shareEntryValid = false;
    _waitingLink = null;
    _pendingJob = null;
    return ++_externalIntentRevision;
  }

  void _openJob(NotificationTarget target) =>
      _queueExternalNavigation(() => _openJobAtRoot(target));

  void _openJobAtRoot(NotificationTarget target) {
    if (!_schedulesKnown) {
      _pendingJob = target;
      return;
    }
    if (!_schedules) {
      _breadcrumbs('nav.notification.ignored', {
        'kind': 'job',
        'reason': 'unavailable',
      });
      return;
    }
    _select(_Destination.schedules);
    _schedulesController?.requestOpen(
      target.jobId ?? '',
      profile: target.profile,
    );
  }
}
