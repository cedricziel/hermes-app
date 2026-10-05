import 'bot_mode_roster_repository.dart';

/// Explicit canonical identity; friendly labels never decide session ownership.
class BotChatContext {
  const BotChatContext({
    required this.bot,
    required this.rootId,
    required this.storedId,
    this.peers = const [],
    this.protocolEnabled = true,
  });
  final BotModeBot bot;
  final String rootId;
  final String storedId;
  final List<BotModeBot> peers;
  final bool protocolEnabled;
  String get title => bot.title;
  String get handle => bot.name == 'default' ? 'hermes' : bot.name;
  BotChatContext withStoredId(String value) => BotChatContext(
    bot: bot,
    rootId: rootId,
    storedId: value,
    peers: peers,
    protocolEnabled: protocolEnabled,
  );

  /// Suggestions only apply to a token beginning at a word boundary, so an
  /// email address and unknown text remain ordinary user text.
  List<BotMention> suggestions(String text, int caret) {
    if (!protocolEnabled || caret < 0 || caret > text.length) return const [];
    final match = RegExp(r'(?:^|\s)@([a-zA-Z0-9_-]*)$')
        .firstMatch(text.substring(0, caret));
    if (match == null) return const [];
    final query = match.group(1)!.toLowerCase();
    final start = caret - query.length - 1;
    final handles = <String, List<BotModeBot>>{};
    for (final peer in peers) {
      if (peer.serverId != bot.serverId || peer.name == bot.name) continue;
      final handle = peer.name == 'default' ? 'hermes' : peer.name;
      handles.putIfAbsent(handle, () => []).add(peer);
    }
    return [
      for (final entry in handles.entries)
        if (entry.value.length == 1 &&
            (entry.key.toLowerCase().startsWith(query) ||
                entry.value.single.title.toLowerCase().startsWith(query)))
          BotMention(entry.value.single.title, entry.key, start, caret),
    ];
  }
}

class BotMention {
  const BotMention(this.title, this.handle, this.start, this.end);
  final String title;
  final String handle;
  final int start;
  final int end;
}
