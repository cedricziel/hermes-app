part of 'app_shell.dart';

extension _AppShellWatchers on _AppShellState {
  void _onWindowless(bool windowless) {
    _windowless = windowless;
    // The last window closing is what a crash report should show.
    if (windowless) _breadcrumbs('app.lifecycle', {'state': 'windowless'});
    _syncSchedulesForeground();
  }

  void _syncSchedulesForeground() =>
      _schedulesController?.foreground = _appForeground && !_windowless;
}
