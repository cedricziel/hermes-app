part of 'app_shell.dart';

extension _AppShellPlatformHint on _AppShellState {
  /// Asks once per sign-in or start whether to add the app's hint to the
  /// profiles that need it.
  Future<void> _offerHint(
    HermesRepositories repositories,
    String server,
  ) async {
    if (!mounted) return;
    final offer = PlatformHintOffer(
      repository: repositories.platformHint,
      profileList: repositories.profiles,
      server: server,
      breadcrumbs: _breadcrumbs,
    );
    try {
      if (await offer.check() && mounted) {
        await showPlatformHintPrompt(context, offer);
      }
    } finally {
      offer.dispose();
    }
  }
}
