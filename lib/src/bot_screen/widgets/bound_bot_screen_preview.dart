import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../telemetry/breadcrumbs.dart';
import '../bot_screen_card_model.dart';
import '../bot_screen_controller.dart';
import '../bot_screen_preview_model.dart';
import 'bot_screen_preview.dart';
import 'bound_bot_screen_card.dart' show BoundBotScreenCard;

/// [BotScreenPreview] over [controller]: the still preview under the
/// `computer_use` call of the reply [replyId], which draws nothing until the
/// profile's screen runs.
///
/// It asks the controller for frames only while some part of it is on screen
/// (and its page is not covered by another route), so a preview that the
/// transcript list built in its cache extent but nobody sees holds no watch
/// and causes no request. A hidden preview keeps a one pixel placeholder under
/// the detector: a box with no area is never reported as visible, and the
/// watch is what brings the status in.
class BoundBotScreenPreview extends StatefulWidget {
  const BoundBotScreenPreview({
    super.key,
    required this.controller,
    required this.replyId,
    this.onTap,
  });

  final BotScreenController controller;

  /// The reply the preview belongs to, which `bot_screen.preview.shown` is
  /// recorded once for.
  final String replyId;
  final VoidCallback? onTap;

  @override
  State<BoundBotScreenPreview> createState() => _BoundBotScreenPreviewState();
}

class _BoundBotScreenPreviewState extends State<BoundBotScreenPreview> {
  final _detectorKey = UniqueKey();
  BotScreenWatch? _watch;
  var _onScreen = false;
  var _pageShown = true;
  var _breadcrumbs = Breadcrumbs.none;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_recordShown);
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
      oldWidget.controller.removeListener(_recordShown);
      widget.controller.addListener(_recordShown);
      _release();
      _syncWatch();
    }
  }

  void _visibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    _onScreen = info.visibleFraction > 0;
    _syncWatch();
    _recordShown();
  }

  void _syncWatch() {
    if (_onScreen && _pageShown) {
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
    final controller = widget.controller;
    if (!_onScreen ||
        controller.shown.previewReply == widget.replyId ||
        !_model().visible) {
      return;
    }
    controller.shown.previewReply = widget.replyId;
    _breadcrumbs('bot_screen.preview.shown');
  }

  void _tapped() {
    _breadcrumbs('bot_screen.preview.tapped');
    widget.onTap?.call();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_recordShown);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VisibilityDetector(
    key: _detectorKey,
    onVisibilityChanged: _visibilityChanged,
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final model = _model();
        if (model.visible) {
          return BotScreenPreview(
            model: model,
            onTap: widget.onTap == null ? null : _tapped,
          );
        }
        // Nothing to say on a server without a Bot Screen; otherwise keep the
        // placeholder, so the detector still sees the preview and the status
        // is read.
        return widget.controller.unsupported
            ? const SizedBox.shrink()
            : const SizedBox(height: 1);
      },
    ),
  );
}
