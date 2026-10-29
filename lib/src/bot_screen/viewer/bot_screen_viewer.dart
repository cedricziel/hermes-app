import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../telemetry/breadcrumbs.dart';
import '../../widgets/adaptive_sheet.dart';
import '../input/screen_gesture_layer.dart';
import '../input/screen_input.dart';
import '../input/screen_keyboard.dart';
import '../input/screen_paste.dart';
import '../input/soft_keyboard.dart';
import '../rfb/rfb_client.dart' show Framebuffer;
import '../takeover_setting.dart';
import '../widgets/bot_screen_desktop_tools.dart';
import '../widgets/bot_screen_key_bar.dart';
import '../widgets/bot_screen_viewer_view.dart';
import '../widgets/force_hand_back.dart';
import '../widgets/takeover_confirmation.dart';
import '../widgets/trackpad_cursor.dart';
import 'bot_screen_viewer_controller.dart';

/// [BotScreenViewerView] over [controller]: the picture of its framebuffer,
/// the actions its phase and its control offer, and, while this device is in
/// control, the input: the gesture layer over the picture, the hardware keys,
/// the on-screen keyboard and Paste.
///
/// It tells the controller whether the route it is on is on screen (a route
/// above it that covers it pauses the stream), and closes on Escape and the
/// system's dismiss action, except while this device is in control, when
/// Escape belongs to the screen and the viewer closes through its Close button
/// or the reserved key (⌘. on a Mac, F8 elsewhere). Take over asks first
/// unless [takeover] says the user chose not to be asked. [breadcrumbs] gets
/// `bot_screen.takeover.pressed`, `bot_screen.handback.pressed`,
/// `bot_screen.force_handback.pressed` and `bot_screen.input.mode`, with fixed
/// words only.
class BotScreenViewer extends StatefulWidget {
  const BotScreenViewer({
    super.key,
    required this.controller,
    required this.profile,
    required this.presentation,
    required this.onClose,
    this.takeover,
    this.breadcrumbs = Breadcrumbs.none,
  });

  final BotScreenViewerController controller;

  /// The profile's name for the header.
  final String profile;
  final BotScreenViewerPresentation presentation;
  final VoidCallback onClose;

  /// Whether to ask before taking over, kept per account; null always asks and
  /// remembers nothing.
  final TakeoverSetting? takeover;
  final Breadcrumbs breadcrumbs;

  @override
  State<BotScreenViewer> createState() => _BotScreenViewerState();
}

class _BotScreenViewerState extends State<BotScreenViewer> {
  final _keys = FocusNode(debugLabel: 'bot screen keys');
  final _zoom = TransformationController();
  final _pointer = ValueNotifier(Offset.zero);
  var _mode = ScreenGestureMode.touch;
  SoftKeyboard? _soft;
  ScreenInput? _softFor;
  String? _notice;
  Timer? _noticeTimer;
  var _wasInControl = false;
  late final AppLifecycleListener _lifecycle;

  BotScreenViewerController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _keys.addListener(_focusChanged);
    _controller.addListener(_controlChanged);
    // A computer's window that loses the keyboard to Alt+Tab or a click
    // elsewhere is still in the foreground, and never sees the key-ups.
    _lifecycle = AppLifecycleListener(onInactive: _releaseHeld);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route above that covers this one turns its tickers off, as for
    // `BotScreenDemand`. The setter tells its listeners a microtask later, so
    // it is safe while the tree builds.
    _controller.visible = TickerMode.valuesOf(context).enabled;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.removeListener(_controlChanged);
    _keys.removeListener(_focusChanged);
    _soft?.hide();
    _noticeTimer?.cancel();
    _keys.dispose();
    _zoom.dispose();
    _pointer.dispose();
    super.dispose();
  }

  /// Keys and buttons the person was holding when the focus or the window left
  /// are let go of, since their release would never come.
  void _releaseHeld() => _controller.input?.releaseAll();

  void _focusChanged() {
    if (!_keys.hasFocus) _releaseHeld();
  }

  /// Takes the keyboard focus when this device takes control, and closes the
  /// on-screen keyboard and the notice when it stops being in control.
  void _controlChanged() {
    final inControl = _controller.inControl;
    if (inControl && !_wasInControl) {
      _keys.requestFocus();
      // The virtual pointer of Trackpad mode starts in the middle.
      final picture = _controller.framebuffer;
      if (picture != null) {
        _pointer.value = Offset(picture.width / 2, picture.height / 2);
      }
    } else if (!inControl && _wasInControl) {
      _soft?.hide();
      _soft = null;
      _softFor = null;
      _notice = null;
      _mode = ScreenGestureMode.touch;
    }
    _wasInControl = inControl;
    // The keyboard belongs to the stream's input, which goes with the stream.
    if (inControl && _soft != null && !identical(_softFor, _controller.input)) {
      _soft!.hide();
      _soft = null;
      _softFor = null;
    }
  }

  bool get _touch =>
      Theme.of(context).platform == TargetPlatform.iOS ||
      Theme.of(context).platform == TargetPlatform.android;

  Future<void> _takeOver() async {
    widget.breadcrumbs('bot_screen.takeover.pressed');
    if (!await _confirmed() || !mounted) return;
    await _controller.takeOver();
  }

  /// Whether the user is happy to take over: not asked again when they said
  /// so for this account.
  Future<bool> _confirmed() async {
    final setting = widget.takeover;
    if (setting != null && await setting.skipsConfirmation()) return true;
    if (!mounted) return false;
    final dontAskAgain = await showAdaptiveSheet<bool>(
      context,
      builder: (sheet) => TakeoverConfirmation(
        offerDontAskAgain: setting != null,
        onCancel: () => Navigator.pop(sheet),
        onConfirm: (dontAskAgain) => Navigator.pop(sheet, dontAskAgain),
      ),
    );
    if (dontAskAgain == null) return false;
    if (dontAskAgain) await setting?.skipConfirmation();
    return true;
  }

  void _handBack() {
    widget.breadcrumbs('bot_screen.handback.pressed');
    unawaited(_controller.handBack());
  }

  /// [context] is below the viewer's own messenger, so a failure is said
  /// inside the viewer and not behind it.
  void _forceHandBack(BuildContext context) {
    widget.breadcrumbs('bot_screen.force_handback.pressed');
    unawaited(confirmForceHandBack(context, _controller.forceHandBack));
  }

  void _setMode(ScreenGestureMode mode) {
    widget.breadcrumbs('bot_screen.input.mode', {'mode': mode.name});
    setState(() => _mode = mode);
  }

  Future<void> _paste() async {
    final outcome = await _controller.paste();
    if (!mounted) return;
    switch (outcome) {
      case PasteOutcome.notLatin1 || PasteOutcome.tooLarge:
        _say("This text can't be pasted to the screen.");
      case PasteOutcome.pasted || PasteOutcome.empty || PasteOutcome.closed:
        break;
    }
  }

  /// Shows [text] under the header for a few seconds.
  void _say(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 5), _clearNotice);
  }

  void _clearNotice() {
    _noticeTimer?.cancel();
    if (mounted) setState(() => _notice = null);
  }

  /// The on-screen keyboard of [input], made when first asked for.
  SoftKeyboard _keyboardOf(ScreenInput input) {
    if (_soft == null || !identical(_softFor, input)) {
      _soft?.hide();
      _softFor = input;
      _soft = SoftKeyboard(
        onText: input.keyboard.typeText,
        onBackspace: () => input.keyboard.tap(ScreenKeys.backSpace),
        onReturn: () => input.keyboard.tap(ScreenKeys.enter),
        // The system can close the connection (a dismissed keyboard on some
        // platforms); the key bar shows it.
        onClosed: () {
          if (mounted) setState(() {});
        },
      );
    }
    return _soft!;
  }

  /// Shows the keyboard unless it is on screen, which hides it. Attached does
  /// not mean on screen: the person can dismiss it with the system's own key.
  void _toggleKeyboard(ScreenInput input) {
    final soft = _keyboardOf(input);
    // A one-off read: a dependency would rebuild the viewer with every frame
    // of the keyboard's animation.
    final onScreen = View.of(context).viewInsets.bottom > 0;
    setState(soft.visible && onScreen ? soft.hide : soft.show);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final input = _controller.input;
    if (input == null) return KeyEventResult.ignored;
    switch (input.keyboard.handle(event)) {
      case ScreenKeyResult.sent || ScreenKeyResult.consumed:
        return KeyEventResult.handled;
      case ScreenKeyResult.paste:
        unawaited(_paste());
        return KeyEventResult.handled;
      case ScreenKeyResult.close:
        widget.onClose();
        return KeyEventResult.handled;
      case ScreenKeyResult.ignored:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) => Actions(
    // Escape is `DismissIntent` in the app's default shortcuts, and a widget
    // handler, not a menu chord: no menu item owns it.
    actions: {
      DismissIntent: CallbackAction<DismissIntent>(
        // While this device is in control Escape is for the screen.
        onInvoke: (_) {
          if (!_controller.inControl) widget.onClose();
          return null;
        },
      ),
    },
    child: Focus(
      focusNode: _keys,
      autofocus: true,
      onKeyEvent: _onKey,
      // The viewer is a route of its own, so it has a messenger of its own:
      // a snackbar of the screen below would be hidden behind it.
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final controller = _controller;
              final framebuffer = controller.framebuffer;
              final input = controller.input;
              final platform = Theme.of(context).platform;
              final touch = _touch;
              final size = framebuffer == null
                  ? Size.zero
                  : Size(
                      framebuffer.width.toDouble(),
                      framebuffer.height.toDouble(),
                    );
              return BotScreenViewerView(
                phase: controller.phase,
                profile: widget.profile,
                presentation: widget.presentation,
                picture: framebuffer == null
                    ? null
                    : FramebufferPicture(
                        framebuffer: framebuffer,
                        revision: controller.revision,
                      ),
                aspectRatio: framebuffer == null
                    ? 16 / 10
                    : (framebuffer.width / framebuffer.height).clamp(0.5, 3.0),
                control: controller.control,
                lostText: controller.lostText,
                canForce: controller.someoneElseInControl,
                onClose: widget.onClose,
                onRetry: controller.retry,
                onStart: () => controller.startScreen(),
                onTakeOver: controller.canTakeOver ? _takeOver : null,
                onHandBack: _handBack,
                onForceHandBack: () => _forceHandBack(context),
                onDismissLost: controller.dismissLost,
                notice: _notice,
                onDismissNotice: _clearNotice,
                transformation: _zoom,
                // A mouse wheel over the picture is the screen's, not a zoom; a
                // finger's pinch stays.
                scaleEnabled: input == null || touch,
                stageOverlay: input == null || framebuffer == null
                    ? null
                    : ScreenGestureLayer(
                        sink: input.sink,
                        framebuffer: size,
                        transformation: _zoom,
                        virtualPointer: _pointer,
                        enabled: true,
                        mode: _mode,
                      ),
                pictureOverlay:
                    input != null &&
                        touch &&
                        _mode == ScreenGestureMode.trackpad &&
                        framebuffer != null
                    ? TrackpadCursor(pointer: _pointer, framebuffer: size)
                    : null,
                keyBar: input != null && touch
                    ? ListenableBuilder(
                        listenable: Listenable.merge([
                          input.keyboard.ctrl,
                          input.keyboard.alt,
                        ]),
                        builder: (context, _) => BotScreenKeyBar(
                          mode: _mode,
                          ctrl: input.keyboard.ctrl.value,
                          alt: input.keyboard.alt.value,
                          keyboardOpen: _soft?.visible ?? false,
                          onMode: _setMode,
                          onEscape: () => input.keyboard.tap(ScreenKeys.escape),
                          onTab: () => input.keyboard.tap(ScreenKeys.tab),
                          onLeft: () =>
                              input.keyboard.tap(ScreenKeys.arrowLeft),
                          onRight: () =>
                              input.keyboard.tap(ScreenKeys.arrowRight),
                          onToggleCtrl: () => input.keyboard.ctrl.value =
                              !input.keyboard.ctrl.value,
                          onToggleAlt: () => input.keyboard.alt.value =
                              !input.keyboard.alt.value,
                          onToggleKeyboard: () => _toggleKeyboard(input),
                          onPaste: _paste,
                        ),
                      )
                    : null,
                tools: input != null && !touch
                    ? BotScreenDesktopTools(
                        onPaste: _paste,
                        onSendF8: platform == TargetPlatform.macOS
                            ? null
                            : () => input.keyboard.tap(ScreenKeys.f8),
                      )
                    : null,
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// What turns RGBA pixels into an image; `dart:ui`'s, unless a test says
/// otherwise.
typedef PixelDecoder = void Function(
  Uint8List pixels,
  int width,
  int height,
  ui.PixelFormat format,
  ui.ImageDecoderCallback callback,
);

/// The framebuffer as an image. Each change is turned into an image at most
/// once per frame, and the previous image is disposed once the next is ready.
class FramebufferPicture extends StatefulWidget {
  const FramebufferPicture({
    super.key,
    required this.framebuffer,
    required this.revision,
    this.decode = ui.decodeImageFromPixels,
  });

  final Framebuffer framebuffer;

  /// Makes the image; the engine's unless a test says otherwise.
  final PixelDecoder decode;

  /// Changes whenever the framebuffer's pixels do.
  final int revision;

  @override
  State<FramebufferPicture> createState() => _FramebufferPictureState();
}

class _FramebufferPictureState extends State<FramebufferPicture> {
  ui.Image? _image;
  Object? _shown;
  var _scheduled = false;
  var _decoding = false;

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(FramebufferPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    _request();
  }

  /// Asks for an image of the pixels as they are in the next frame.
  void _request() {
    if (_scheduled || _decoding) return;
    final latest = (widget.framebuffer, widget.revision);
    if (_shown == latest) return;
    _scheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _scheduled = false;
      if (mounted) _decode();
    });
  }

  void _decode() {
    final framebuffer = widget.framebuffer;
    final revision = widget.revision;
    _decoding = true;
    // The engine copies the pixels at once, so the client may paint into the
    // buffer again straight away.
    widget.decode(
      framebuffer.rgba,
      framebuffer.width,
      framebuffer.height,
      ui.PixelFormat.rgba8888,
      (image) {
        _decoding = false;
        if (!mounted) {
          image.dispose();
          return;
        }
        final previous = _image;
        setState(() {
          _image = image;
          _shown = (framebuffer, revision);
        });
        previous?.dispose();
        _request();
      },
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const ColoredBox(color: Colors.black);
    return RawImage(
      image: image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
