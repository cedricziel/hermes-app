part of 'app_shell.dart';

extension _AppShellBots on _AppShellState {
  Future<void> _openBot(BotModeBot bot) async {
    if (!_authorizedOwner) return;
    final version = ++_botOpenVersion;
    final intent = _beginExternalNavigation();
    final owner = _auth?.ownerGeneration;
    _externalNavigation.cancel();
    bool current() =>
        _authorizedOwner &&
        _auth?.ownerGeneration == owner &&
        version == _botOpenVersion &&
        intent == _externalIntentRevision;
    try {
      final roster = await _botsRepository!.load();
      if (!current()) return;
      final currentBot = roster.bots.singleWhere(
        (candidate) => candidate.identity == bot.identity,
      );
      final chat = await _botChats!.open(currentBot);
      if (!current()) return;
      _externalNavigation.request((_) {
        if (!current()) return;
        _openRequests.request(
          NotificationTarget(threadId: chat.storedId, profile: chat.profile),
          bot: BotChatContext(
            bot: currentBot,
            rootId: chat.rootId,
            storedId: chat.storedId,
            peers: roster.bots,
            protocolEnabled: roster.supported,
          ),
        );
        if (current()) _showChat();
      });
    } on Object {
      if (mounted && current()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the bot chat. Retry from Bots.'),
          ),
        );
      }
    }
  }

  void _openGroup(GroupRoom room) {
    final groups = _groups;
    if (groups == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => GroupChatScreen(
          repository: groups,
          room: room,
          onDisbanded: () {
            dismissRoute(routeContext);
          },
        ),
      ),
    );
  }
}
