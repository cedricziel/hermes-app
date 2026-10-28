part of 'chat_screen.dart';

/// The chat profile's Bot Screen: one controller on the shared gateway, held
/// while the screen is open, replaced when the chat moves to another profile,
/// and kept from asking for frames unless the app is resumed, unlocked and,
/// on a Mac, has a window on screen.
extension _ChatScreenBotScreen on _ChatScreenState {
  void _initBotScreen(ChatTransport? transport) {
    if (transport is GatewayRequester &&
        transport is GatewayConnectionTransport) {
      _screenGateway = (
        requests: transport as GatewayRequester,
        events: transport as GatewayConnectionTransport,
      );
    }
    _screenLock = _maybeRead<AppLockController>()
      ?..addListener(_onBotScreenGates);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
      _windowlessChanges = MacApp.windowlessChanges.listen((windowless) {
        _windowless = windowless;
        _syncBotScreenGates();
      });
    }
    _syncBotScreen();
  }

  /// Makes sure the controller belongs to the chat's profile.
  void _syncBotScreen() {
    final gateway = _screenGateway;
    if (gateway == null ||
        (_screen != null && _screenProfile == _chat.profile)) {
      return;
    }
    final telemetry =
        HermesRepositories.maybeOf(context)?.telemetry ??
        const ConnectionTelemetry();
    final previous = _screen;
    _screenProfile = _chat.profile;
    _screen = BotScreenController(
      BotScreenRepository(
        gateway.requests.requestKeepingConnection,
        telemetry: telemetry,
      ),
      gateway.events.connectionEvents,
      profile: _screenProfile,
      events: telemetry.events,
    );
    _syncBotScreenGates();
    if (previous != null) {
      // The panel still listens to it until the frame that replaces it.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  void _syncBotScreenGates() {
    // Not `_routeVisible`: the phone's Activity sheet is a route of its own
    // above the chat, and it is what asks for the frames.
    _screen
      ?..foreground = _foreground && widget.visible && !_windowless
      ..unlocked = !(_screenLock?.covered ?? false);
  }

  void _disposeBotScreen() {
    _screenLock?.removeListener(_onBotScreenGates);
    _screen?.dispose();
  }
}
