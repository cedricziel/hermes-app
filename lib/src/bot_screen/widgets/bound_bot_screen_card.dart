import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../chat/chat_models.dart';
import '../../telemetry/breadcrumbs.dart';
import '../bot_screen_card_model.dart';
import '../bot_screen_controller.dart';
import 'bot_screen_card.dart';
import 'force_hand_back.dart';

/// What the last scan of a thread found, and what it was a scan of.
class _ScreenScan {
  const _ScreenScan(this.messages, this.lastToolCalls, this.used);

  final int messages;
  final int lastToolCalls;
  final bool used;
}

final _scans = Expando<_ScreenScan>();

/// Whether [thread] holds a `computer_use` tool call, which lists the Bot
/// screen card even while the screen is off.
///
/// The panel asks on every chat change, which includes each streamed delta,
/// so the answer is kept per thread and scanned again only when the thread has
/// another message or its newest message another tool call (the only place a
/// call can arrive).
bool threadUsedScreen(ChatThread thread) {
  final messages = thread.messages;
  final count = messages.length;
  final lastCalls = count == 0 ? 0 : messages[count - 1].toolCalls.length;
  final scan = _scans[thread];
  if (scan != null &&
      scan.messages == count &&
      scan.lastToolCalls == lastCalls) {
    return scan.used;
  }
  final used = messages.any(
    (message) => message.toolCalls.any((call) => call.name == kComputerUseTool),
  );
  _scans[thread] = _ScreenScan(count, lastCalls, used);
  return used;
}

/// [BotScreenCard] over [controller], drawing [model] (which the Activity
/// panel derived to decide whether to list the card at all).
class BoundBotScreenCard extends StatelessWidget {
  const BoundBotScreenCard({
    super.key,
    required this.controller,
    required this.model,
    this.onEnlarge,
  });

  final BotScreenController controller;
  final BotScreenCardModel model;

  /// Opens the live viewer; Enlarge is hidden without it.
  final VoidCallback? onEnlarge;

  @override
  Widget build(BuildContext context) {
    final command = switch (model) {
      BotScreenNotInstalled(:final command) => command,
      _ => null,
    };
    return BotScreenCard(
      model: model,
      breadcrumbs: breadcrumbsOf(context),
      shown: controller.shown,
      onStart: controller.start,
      onInstall: controller.canInstall ? controller.startInstall : null,
      onRetry: controller.retry,
      onEnlarge: onEnlarge,
      onForceHandBack: () =>
          confirmForceHandBack(context, controller.forceHandBack),
      onCopyCommand: command == null
          ? null
          : () => Clipboard.setData(ClipboardData(text: command)),
    );
  }

  static Breadcrumbs breadcrumbsOf(BuildContext context) {
    try {
      return context.read<Breadcrumbs>();
    } on ProviderNotFoundException {
      return Breadcrumbs.none;
    }
  }
}

/// Asks [controller] for frames while it is mounted and visible, and lets go
/// of them otherwise. Mount it around the Activity panel: that is what keeps
/// the status and frames coming (and the card listed), whether or not the card
/// shows yet.
///
/// A panel that is not painted (an offstage page, a [Visibility] with
/// `visible: false`) or that sits under a pushed page (its tickers are off)
/// counts as hidden, as for `GroupChatScreen`.
class BotScreenDemand extends StatefulWidget {
  const BotScreenDemand({
    super.key,
    required this.controller,
    required this.child,
  });

  final BotScreenController controller;
  final Widget child;

  @override
  State<BotScreenDemand> createState() => _BotScreenDemandState();
}

class _BotScreenDemandState extends State<BotScreenDemand> {
  BotScreenWatch? _watch;
  var _visible = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = Visibility.of(context) && TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(BotScreenDemand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      _release();
      _sync();
    }
  }

  void _sync() {
    if (_visible) {
      _watch ??= widget.controller.watch();
    } else {
      _release();
    }
  }

  void _release() {
    _watch?.release();
    _watch = null;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
