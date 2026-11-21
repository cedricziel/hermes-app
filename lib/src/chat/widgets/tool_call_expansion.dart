/// What the reader opened among the tool calls of a chat: which
/// `ToolCallCard`s and which `ToolCallGroup`s.
///
/// It is held above the message list, so it outlives a row that scrolls out of
/// the list's window and the list remounting (the blank-list recovery). A
/// group or a card read from here comes back as the reader left it.
///
/// Each run of tool calls is a scope (the id of its message); inside it a card
/// is the call's id, or its place in the run for a call the server sent no id
/// for. A group is open only while the reader has it open: a group they folded
/// has no entry, so it stays folded when more calls arrive.
///
/// Holds no text of the chat beyond those ids, and is never logged.
class ToolCallExpansionStore {
  final _cards = <String>{};
  final _groups = <String>{};
  final _lone = <String>{};

  static String _card(String scope, String key) => '$scope\u0000$key';

  bool cardOpen(String scope, String key) => _cards.contains(_card(scope, key));

  void setCardOpen(String scope, String key, bool open) {
    if (open) {
      _cards.add(_card(scope, key));
    } else {
      _cards.remove(_card(scope, key));
    }
  }

  /// A call that was still being written has no id until it starts: its card
  /// keeps its state under the new key. Returns whether it was open.
  bool moveCard(String scope, String from, String to) {
    if (!_cards.remove(_card(scope, from))) return false;
    _cards.add(_card(scope, to));
    return true;
  }

  /// Forgets the positional (`at:`) cards of [scope] whose key is not in
  /// [keys]: a run that was split or rewritten no longer holds those calls,
  /// and a positional key must not open whichever call comes to stand at its
  /// place. A card keyed by id stays: a run can shrink for a moment and the
  /// call come back.
  void retainCards(String scope, Set<String> keys) {
    final prefix = '$scope\u0000at:';
    _cards.removeWhere(
      (c) =>
          c.startsWith(prefix) && !keys.contains(c.substring(scope.length + 1)),
    );
  }

  /// Whether the reader opened the card of a run that had one call, and no
  /// group has formed around it yet. Taken once ([takeLoneOpened]) by the
  /// group that forms, so a group the reader folds stays folded.
  void setLoneOpened(String scope, bool opened) {
    if (opened) {
      _lone.add(scope);
    } else {
      _lone.remove(scope);
    }
  }

  bool takeLoneOpened(String scope) => _lone.remove(scope);

  bool groupOpen(String scope) => _groups.contains(scope);

  void setGroupOpen(String scope, bool open) {
    if (open) {
      _groups.add(scope);
    } else {
      _groups.remove(scope);
    }
  }

  Object? _chat;
  String? _chatId;
  String? _profile;
  var _following = false;

  /// Says which chat the screen shows now, and forgets everything when it is
  /// another one: another profile, or another chat object with another id. The
  /// same chat read again (the thread list rebuilds idle threads on a resume)
  /// comes as a new [chat] object with the same [chatId] and keeps what was
  /// opened, and a new chat given its stored id keeps its object.
  void follow({
    required String? profile,
    required Object? chat,
    required String? chatId,
  }) {
    if (_following &&
        (profile != _profile || !identical(chat, _chat) && chatId != _chatId)) {
      clear();
    }
    _following = true;
    _profile = profile;
    _chat = chat;
    _chatId = chatId;
  }

  /// Forgets everything: the chat changed, or the session ended.
  void clear() {
    _cards.clear();
    _groups.clear();
    _lone.clear();
  }

  bool get isEmpty => _cards.isEmpty && _groups.isEmpty && _lone.isEmpty;
}
