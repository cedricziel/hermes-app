part of 'chat_screen.dart';

extension _ChatScreenReadAloud on _ChatScreenState {
  /// Asks whether the shown profile can speak, and offers Read aloud on its
  /// replies only while `voice-config` says so. A profile switch hides it at
  /// once, so a reply is never spoken with another profile's voice.
  Future<void> _refreshReadAloud() async {
    final repository = _chat.repository;
    final store = _maybeRead<MediaStore?>();
    if (repository == null || store == null) return;
    final profile = _chat.profile;
    _readAloudAsked = (profile: profile);
    final epoch = ++_readAloudEpoch;
    if (_readAloud case final old? when old.profile != profile) {
      old.cancel();
      _rebuild(() => _readAloud = null);
    }
    final support = await repository.voiceSupport(profile: profile);
    if (!mounted || epoch != _readAloudEpoch || _chat.profile != profile) {
      return;
    }
    final current = _readAloud;
    final next = !support.textToSpeech
        ? null
        : current != null && current.profile == profile
        ? current
        : ReadAloud(
            profile: profile,
            store: store,
            synthesize: (text, cancellation) => repository.synthesize(
              text,
              profile: profile,
              cancellation: cancellation,
            ),
          );
    if (identical(next, current)) return;
    current?.cancel();
    _rebuild(() => _readAloud = next);
  }
}
