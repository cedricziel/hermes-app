import 'package:uuid/uuid.dart';

import '../../chat/hermes_chat_repository.dart';

/// The `tts-lease` of one call: a warm-up of the profile's speech provider,
/// held while the call is open. Its name is random per call and says nothing
/// of the server, the profile or the chat.
class CallTtsLease {
  CallTtsLease(this._repository, {this.profile})
    : id = 'app:conversation:${const Uuid().v4()}';

  final HermesChatRepository _repository;
  final String? profile;
  final String id;

  /// Throws when the server refuses; the call ignores that.
  Future<void> hold() =>
      _repository.holdTextToSpeech(id, active: true, profile: profile);

  Future<void> release() =>
      _repository.holdTextToSpeech(id, active: false, profile: profile);
}
