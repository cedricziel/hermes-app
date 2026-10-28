import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../telemetry/breadcrumbs.dart';
import '../bot_screen_card_model.dart';
import '../bot_screen_controller.dart';
import '../bot_screen_preview_model.dart';
import 'bot_screen_preview.dart';
import 'bound_bot_screen_card.dart' show BoundBotScreenCard;
import 'on_screen.dart';

/// What the previews of one controller share: which reply owns the screen's
/// preview, the one that was last recorded as shown, and a stable key per
/// reply.
class _PreviewRegistry extends ChangeNotifier {
  static const _keptKeys = 4;

  final _keys = <String, GlobalKey>{};

  /// The newest pending reply that has a preview, which is the only one that
  /// draws it.
  ({String replyId, DateTime startedAt})? owner;

  /// The reply `bot_screen.preview.shown` was last recorded for.
  String? recorded;

  GlobalKey keyFor(String replyId) {
    final key = _keys.remove(replyId) ?? GlobalKey(debugLabel: 'preview');
    _keys[replyId] = key;
    if (_keys.length > _keptKeys) _keys.remove(_keys.keys.first);
    return key;
  }

  void changed() => notifyListeners();
}

final _registries = Expando<_PreviewRegistry>();

_PreviewRegistry _registryOf(BotScreenController controller) =>
    _registries[controller] ??= _PreviewRegistry();

/// [BotScreenPreview] over [controller]: the still preview under the
/// `computer_use` call of the reply [replyId], which draws nothing until the
/// profile's screen runs.
///
/// It asks the controller for frames only while some part of it is on screen
/// (and its page is not covered by another route), so a preview that the
/// transcript list built in its cache extent but nobody sees holds no watch
/// and causes no request. A preview with nothing to show still takes part: the
/// watch is what reads the screen's status.
///
/// Give it [keyFor] as its key, so it keeps its state, and with it its frame
/// and its watch, when its place in the tree changes (a call joining a run, an
/// approval appearing). Of several replies that are pending at once, only the
/// newest ([startedAt]) shows the preview.
class BoundBotScreenPreview extends StatefulWidget {
  const BoundBotScreenPreview({
    super.key,
    required this.controller,
    required this.replyId,
    required this.startedAt,
    this.onTap,
  });

  /// The key for [replyId]'s preview, the same one each time.
  static GlobalKey keyFor(BotScreenController controller, String replyId) =>
      _registryOf(controller).keyFor(replyId);

  final BotScreenController controller;

  /// The reply the preview belongs to, which `bot_screen.preview.shown` is
  /// recorded once for.
  final String replyId;

  /// When the reply began, which decides the newest of several.
  final DateTime startedAt;
  final VoidCallback? onTap;

  @override
  State<BoundBotScreenPreview> createState() => _BoundBotScreenPreviewState();
}

class _BoundBotScreenPreviewState extends State<BoundBotScreenPreview> {
  BotScreenWatch? _watch;
  var _onScreen = false;
  var _pageShown = true;
  var _breadcrumbs = Breadcrumbs.none;

  _PreviewRegistry get _registry => _registryOf(widget.controller);

  bool get _isOwner => _registry.owner?.replyId == widget.replyId;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    widget.controller.addListener(_changed);
    _registry.addListener(_changed);
    _claim();
  }

  void _detach(BotScreenController controller) {
    controller.removeListener(_changed);
    final registry = _registryOf(controller)..removeListener(_changed);
    if (registry.owner?.replyId == widget.replyId) {
      registry.owner = null;
      scheduleMicrotask(registry.changed);
    }
  }

  /// Takes the preview over from an older reply, or when nobody has it.
  void _claim() {
    final owner = _registry.owner;
    if (owner != null &&
        owner.replyId != widget.replyId &&
        !widget.startedAt.isAfter(owner.startedAt)) {
      return;
    }
    if (owner?.replyId != widget.replyId) {
      _registry.owner = (replyId: widget.replyId, startedAt: widget.startedAt);
      scheduleMicrotask(_registry.changed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pageShown = TickerMode.valuesOf(context).enabled;
    _breadcrumbs = BoundBotScreenCard.breadcrumbsOf(context);
    _syncWatch();
  }

  @override
  void didUpdateWidget(BoundBotScreenPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _detach(oldWidget.controller);
      _release();
      _attach();
      _syncWatch();
    }
  }

  /// The controller or the ownership changed.
  void _changed() {
    if (!mounted) return;
    _claim();
    _syncWatch();
    _recordShown();
    // Ownership alone does not rebuild the preview below.
    setState(() {});
  }

  void _onScreenChanged(bool onScreen) {
    _onScreen = onScreen;
    _syncWatch();
    _recordShown();
  }

  void _syncWatch() {
    if (_onScreen && _pageShown && _isOwner) {
      _watch ??= widget.controller.watch();
    } else {
      _release();
    }
  }

  void _release() {
    _watch?.release();
    _watch = null;
  }

  BotScreenPreviewModel _model() =>
      BotScreenPreviewModel.from(BotScreenCardModel.from(widget.controller));

  /// Records `bot_screen.preview.shown` the first time this reply's preview is
  /// on screen with something to show.
  void _recordShown() {
    final registry = _registry;
    if (!_onScreen ||
        !_isOwner ||
        registry.recorded == widget.replyId ||
        !_model().visible) {
      return;
    }
    registry.recorded = widget.replyId;
    _breadcrumbs('bot_screen.preview.shown');
  }

  void _tapped() {
    _breadcrumbs('bot_screen.preview.tapped');
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _detach(widget.controller);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = _isOwner ? _model() : const BotScreenPreviewHidden();
    return OnScreen(
      onChanged: _onScreenChanged,
      child: model.visible
          ? BotScreenPreview(
              model: model,
              onTap: widget.onTap == null ? null : _tapped,
            )
          : const SizedBox.shrink(),
    );
  }
}
