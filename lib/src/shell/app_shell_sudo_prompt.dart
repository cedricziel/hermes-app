part of 'app_shell.dart';

extension _AppShellSudoPrompt on _AppShellState {
  /// The sudo password of the Hermes host, asked over whatever page is up.
  /// Nothing is asked once the session is gone; the answer is then a decline.
  Future<String?> _askSudoPassword(
    String host,
    String profile,
    Future<void> ended,
  ) async {
    if (!_authorizedOwner) return null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      // The question would otherwise open on a window nobody can see.
      try {
        await (_windows?.showMainWindow() ?? MacWindow.orderFront());
      } on Object {
        // The question still goes on screen.
      }
      if (!_authorizedOwner) return null;
    }
    if (!mounted) return null;
    return showSudoPasswordPrompt(
      context,
      host: host,
      profile: profile,
      ended: ended,
      breadcrumbs: _breadcrumbs,
    );
  }
}
