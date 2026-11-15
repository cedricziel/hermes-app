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

  /// Forgets the cards of [scope] whose key is not in [keys]: a run that was
  /// split or rewritten no longer holds those calls, and a positional key
  /// must not open whichever call comes to stand at its place.
  void retainCards(String scope, Set<String> keys) {
    final prefix = '$scope\u0000';
    _cards.removeWhere(
      (c) => c.startsWith(prefix) && !keys.contains(c.substring(prefix.length)),
    );
  }

  bool groupOpen(String scope) => _groups.contains(scope);

  void setGroupOpen(String scope, bool open) {
    if (open) {
      _groups.add(scope);
    } else {
      _groups.remove(scope);
    }
  }

  /// Forgets everything: the chat changed, or the session ended.
  void clear() {
    _cards.clear();
    _groups.clear();
  }

  bool get isEmpty => _cards.isEmpty && _groups.isEmpty;
}
