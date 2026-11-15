part of 'chat_screen.dart';

/// "Export chat as JSON": the controller this screen owns and what ends an
/// export early. One controller per State, so a screen rebuilt for a new owner
/// generation never shares one with the old State, whose dispose acts only on
/// its own.
extension _ChatScreenExport on _ChatScreenState {
  void _initExport(HermesRepositories? repositories) {
    final api = repositories?.api;
    if (api == null) return;
    final export = _export = newSessionExportController(
      context,
      api: api,
      telemetry: SessionExportTelemetry(
        repositories!.telemetry,
        _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none,
      ),
    )..addListener(_exportChanged);
    _exportProfile = _chat.profile;
    // App Lock, sign-out and a change of server end an export through the
    // signals that already exist; no screen guards its own.
    _exportLock = _maybeRead<AppLockController>()
      ?..addListener(_checkExportLock);
    _exportWasLocked = _exportLock?.locked ?? false;
    final auth = _avatarAuth;
    _exportAuth = auth?..addListener(_checkExportOwner);
    _exportOwner = auth?.ownerGeneration;
    _exportServer = auth?.baseUrl;
    _exportSignedOut = auth?.signedOut.listen((_) => export.signedOut());
  }

  void _exportChanged() {
    if (mounted) _rebuild(() {});
  }

  void _checkExportLock() {
    final locked = _exportLock?.locked ?? false;
    if (locked && !_exportWasLocked) _export?.locked();
    _exportWasLocked = locked;
  }

  void _checkExportOwner() {
    final auth = _exportAuth;
    if (auth == null) return;
    if (auth.ownerGeneration == _exportOwner && auth.baseUrl == _exportServer) {
      return;
    }
    _exportOwner = auth.ownerGeneration;
    _exportServer = auth.baseUrl;
    _export?.contextChanged();
  }

  /// The chat's profile changed under an export.
  void _syncExport() {
    if (_exportProfile == _chat.profile) return;
    _exportProfile = _chat.profile;
    _export?.contextChanged();
  }

  /// The menu row for [thread]: absent for a chat the server does not hold or
  /// one listed under no profile, disabled while an export runs.
  ExportJsonOffer? _exportJsonOffer(ChatThread? thread) {
    final export = _export;
    final profile = _chat.housekeeping?.profile();
    if (export == null || thread == null || !thread.remote || profile == null) {
      return null;
    }
    return ExportJsonOffer(
      enabled: !export.busy,
      onSelected: () => unawaited(
        showSessionExport(
          context,
          export,
          sessionId: thread.id,
          profile: profile,
          title: thread.title,
        ),
      ),
    );
  }

  void _disposeExport() {
    _exportAuth?.removeListener(_checkExportOwner);
    _exportLock?.removeListener(_checkExportLock);
    _export
      ?..removeListener(_exportChanged)
      ..dispose();
  }
}
