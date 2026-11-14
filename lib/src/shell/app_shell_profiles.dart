part of 'app_shell.dart';

extension _AppShellProfiles on _AppShellState {
  Future<void> _switchProfile(String name) async {
    final switched = await _chatProfiles?.switchTo(name) ?? false;
    if (switched || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not switch profile')));
  }

  /// The profile switcher above the destinations of a Mac sidebar.
  Widget? _profileSwitcher() {
    final profiles = _chatProfiles;
    if (profiles == null) return null;
    return ListenableBuilder(
      listenable: profiles,
      builder: (context, _) => MacProfileSwitcher(
        profiles: profiles.profiles,
        current: profiles.current,
        onSwitch: _switchProfile,
        onNewProfile: () => createProfile(context, profiles.create),
        onManage: () => _select(_Destination.profiles),
      ),
    );
  }
}
