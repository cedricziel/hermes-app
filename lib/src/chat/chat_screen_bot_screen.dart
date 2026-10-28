part of 'chat_screen.dart';

const _desktopPlatforms = {
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
};

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
    final telemetry = _screenTelemetry();
    final previous = _screen;
    // The viewer watches the screen that is being replaced.
    _viewerHandle?.close();
    _screenProfile = _chat.profile;
    final repository = _screenRepository = BotScreenRepository(
      gateway.requests.requestKeepingConnection,
      telemetry: telemetry,
    );
    _screen = BotScreenController(
      repository,
      gateway.events.connectionEvents,
      profile: _screenProfile,
      events: telemetry.events,
      installs: _maybeRead<BotScreenInstalls>(),
    );
    _syncBotScreenGates();
    if (previous != null) {
      // The panel still listens to it until the frame that replaces it.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  ConnectionTelemetry _screenTelemetry() =>
      HermesRepositories.maybeOf(context)?.telemetry ??
      const ConnectionTelemetry();

  /// Whether the app is in front as far as the Bot Screen is concerned. A
  /// desktop window that is only inactive (another app has the focus) is still
  /// on screen, unlike a phone that is showing the notification shade.
  bool get _screenInFront {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) return true;
    return state == AppLifecycleState.inactive &&
        !kIsWeb &&
        _desktopPlatforms.contains(defaultTargetPlatform);
  }

  void _syncBotScreenGates() {
    // Not `_routeVisible`: the phone's Activity sheet is a route of its own
    // above the chat, and it is what asks for the frames.
    final foreground = _screenInFront && widget.visible && !_windowless;
    final unlocked = !(_screenLock?.covered ?? false);
    _screen
      ?..foreground = foreground
      ..unlocked = unlocked;
    _viewer
      ?..foreground = foreground
      ..unlocked = unlocked;
  }

  /// Opens the live, watch-only viewer of the chat profile's screen, from the
  /// Activity card (`source: card`) or the transcript preview (`preview`).
  void _openViewer(String source) {
    final screen = _screen;
    final repository = _screenRepository;
    if (screen == null || repository == null || _viewer != null) return;
    final baseUrl = _maybeRead<AuthController>()?.baseUrl;
    final profile = _screenProfile;
    final controller = _viewer = BotScreenViewerController(
      repository: repository,
      screen: screen,
      openSocket:
          widget.displaySocketOpener ??
          (path, ticket) => baseUrl == null
              ? Future.error(
                  const DisplaySocketError(DisplaySocketErrorKind.unreachable),
                )
              : openDisplaySocket(baseUrl, path, ticket),
      profile: profile,
      telemetry: _screenTelemetry(),
    );
    _syncBotScreenGates();
    controller.start();
    _viewerHandle = showBotScreenViewer(
      context,
      controller: controller,
      profile: profile ?? 'default',
      source: source,
      breadcrumbs: _maybeRead<Breadcrumbs>() ?? Breadcrumbs.none,
      onClosed: () {
        if (identical(_viewer, controller)) {
          _viewer = null;
          _viewerHandle = null;
        }
        controller.dispose();
      },
    );
  }

  void _disposeBotScreen() {
    _screenLock?.removeListener(_onBotScreenGates);
    _viewerHandle?.close();
    _screen?.dispose();
  }
}
