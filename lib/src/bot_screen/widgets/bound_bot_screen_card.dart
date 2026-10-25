import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../chat/chat_models.dart';
import '../../telemetry/breadcrumbs.dart';
import '../bot_screen_card_model.dart';
import '../bot_screen_controller.dart';
import 'bot_screen_card.dart';

/// Whether [thread] holds a `computer_use` tool call, which lists the Bot
/// screen card even while the screen is off.
bool threadUsedScreen(ChatThread thread) => thread.messages.any(
  (message) => message.toolCalls.any((call) => call.name == 'computer_use'),
);

/// [BotScreenCard] over [controller], drawing [model] (which the Activity
/// panel derived to decide whether to list the card at all).
class BoundBotScreenCard extends StatelessWidget {
  const BoundBotScreenCard({
    super.key,
    required this.controller,
    required this.model,
  });

  final BotScreenController controller;
  final BotScreenCardModel model;

  @override
  Widget build(BuildContext context) {
    final command = switch (model) {
      BotScreenNotInstalled(:final command) => command,
      _ => null,
    };
    return BotScreenCard(
      model: model,
      breadcrumbs: _breadcrumbs(context),
      onStart: controller.start,
      onRetry: controller.retry,
      onCopyCommand: command == null
          ? null
          : () => Clipboard.setData(ClipboardData(text: command)),
    );
  }

  static Breadcrumbs _breadcrumbs(BuildContext context) {
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
/// `visible: false`) counts as hidden, as for `KanbanBoardController.active`.
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
    _visible = Visibility.of(context);
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
