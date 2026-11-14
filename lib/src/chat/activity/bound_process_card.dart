import 'dart:async';

import 'package:flutter/widgets.dart';

import '../chat_controller.dart';
import '../process_card_mapper.dart';
import '../process_output_state.dart';
import '../subagents/process_models.dart';
import '../subagents/process_stop_controller.dart';
import '../subagents/subagent_roster.dart';
import '../widgets/confirm_stop_program.dart';
import '../widgets/process_output_card.dart';

/// One program card of the Activity panel, bound to the chat's program list
/// and, once Stop program is pressed, to its own [ProcessStopController].
///
/// The controller is made on the first press and lives with the card; it is
/// bound to the program's [ProcessKey], so a list that refreshes or reorders
/// never moves a confirmation to another card. With [readOnly] (a
/// conversation window, which holds no session) or without a [roster] the
/// card shows what frames and the list said, and offers no Stop.
class BoundProcessCard extends StatefulWidget {
  const BoundProcessCard({
    super.key,
    required this.chat,
    required this.output,
    this.roster,
    this.omittedCards = false,
    this.readOnly = false,
  });

  final ChatController chat;
  final ProcessOutput output;
  final SubagentRoster? roster;
  final bool omittedCards;
  final bool readOnly;

  @override
  State<BoundProcessCard> createState() => _BoundProcessCardState();
}

class _BoundProcessCardState extends State<BoundProcessCard> {
  ProcessStopController? _controller;

  /// Closes an open confirmation: the program ended, or the card went.
  final _ended = ValueNotifier(false);
  var _asking = false;

  @override
  void didUpdateWidget(BoundProcessCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.roster, widget.roster) ||
        widget.readOnly ||
        widget.output.processId != oldWidget.output.processId ||
        _stale(widget.roster)) {
      // Another roster or program, or the same roster now naming another
      // chat id or profile: a stop bound to the old key is not this card's.
      _dropController();
    }
  }

  /// Whether the controller was made for a key the roster no longer names:
  /// a compression gave the chat a new stored id (the roster follows it in
  /// place), or the profile changed. A server's "can't stop programs" holds
  /// only for the connection that said it.
  bool _stale(SubagentRoster? roster) {
    final controller = _controller;
    if (controller == null || roster == null) return false;
    final key = controller.key;
    return key.threadId != roster.threadId ||
        key.profile != roster.profile ||
        (controller.phase == ProcessStopPhase.unsupported &&
            !identical(key.connection, roster.connection));
  }

  void _dropController() {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    _ended.value = true;
    controller
      ..removeListener(_changed)
      ..dispose();
  }

  ProcessStopController? _controllerFor(SubagentRoster roster) {
    if (_stale(roster)) _dropController();
    final existing = _controller;
    if (existing != null) return existing;
    final connection = roster.connection;
    final host = roster.programHostFor(widget.output.processId);
    if (connection == null || host == null) return null;
    _ended.value = false;
    return _controller = ProcessStopController(
      key: ProcessKey(
        threadId: roster.threadId,
        profile: roster.profile,
        connection: connection,
        processId: widget.output.processId,
      ),
      repository: roster.repository,
      host: host,
      events: widget.chat.events,
      breadcrumbs: widget.chat.breadcrumbs,
    )..addListener(_changed);
  }

  void _changed() {
    if (!mounted) return;
    _ended.value = _controller?.confirmationClosed ?? false;
    setState(() {});
  }

  Future<void> _stop() async {
    final roster = widget.roster;
    if (_asking || widget.readOnly || roster == null) return;
    final controller = _controllerFor(roster);
    if (controller == null || !controller.canStop) return;
    controller.startStop();
    if (controller.phase != ProcessStopPhase.confirming) return;
    _asking = true;
    final confirmed = await confirmStopProgram(
      context,
      command: widget.output.command ?? '',
      dismissWhen: _ended,
    );
    _asking = false;
    if (!mounted || !identical(controller, _controller)) return;
    if (confirmed) {
      unawaited(controller.confirmStop());
    } else {
      controller.cancelStop();
    }
  }

  /// Stop program shows while the list says the program runs and a stop can
  /// be asked for, and stays while one is asked, sent (busy) or checked.
  bool get _offersStop {
    final roster = widget.roster;
    if (widget.readOnly || roster == null) return false;
    final controller = _controller;
    if (controller == null) {
      return widget.output.running && roster.connection != null;
    }
    // While the confirmation is open the button stays, so the card does not
    // jump under the dialog; a press then does nothing.
    return controller.canStop ||
        controller.phase == ProcessStopPhase.confirming ||
        controller.phase == ProcessStopPhase.sending ||
        controller.phase == ProcessStopPhase.checking;
  }

  @override
  void dispose() {
    _dropController();
    _ended.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ProcessOutputCard(
      output: widget.output,
      omittedCards: widget.omittedCards,
      onDetails: widget.chat.processOutputDetailsOpened,
      info: processCardInfo(
        widget.output,
        stop: controller == null
            ? ProcessStopStatus.idle
            : processStopStatusOf(controller.phase),
      ),
      onStop: _offersStop ? () => unawaited(_stop()) : null,
    );
  }
}
