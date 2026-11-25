import '../../files/widgets/safe_path_text.dart' show wellFormedText;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/disclosure_toggled.dart';
import '../chat_models.dart';
import '../tool_call_presentation.dart';
import 'tool_call_card.dart';
import 'tool_call_expansion.dart';

/// A run of tool calls the agent made back to back, with no reasoning
/// between them — assistant-ui folds a burst of tool use into one row
/// ("Used 3 tools") instead of a card per call.
///
/// A single call in the run, whether finished or still running, shows as its
/// own [ToolCallCard] with no group chrome. Two or more collapse behind a
/// header naming the call still running, or how many ran once none are; it
/// starts folded and opens on tap, showing each call's own [ToolCallCard].
/// While a call waits on the user's approval the group stays open, so the
/// question is never folded away.
///
/// Which cards the reader opened is kept here, by call, so a card opened while
/// it was the only call stays open when the next call turns the run into a
/// group (which then opens, so the card does not fold away under the reader),
/// and when the group is folded and opened again. A group the reader folded
/// stays folded when more calls arrive.
///
/// That is kept in [expansion] under [expansionScope] when both are given, so
/// it outlives this widget: a row scrolled out of the list and back, or the
/// list mounted anew, shows the cards and the group as the reader left them.
/// Without them it is kept here, for as long as the widget lives.
class ToolCallGroup extends StatefulWidget {
  const ToolCallGroup({
    super.key,
    required this.calls,
    this.approvals = const {},
    this.onAnswerApproval,
    this.preview,
    this.expansion,
    this.expansionScope = '',
  });

  final List<ToolCall> calls;

  /// Drawn right under the run, outside any card: below the card of a run of
  /// one call, below the header of a longer run, so it stays in view while that
  /// is folded. The still picture of the screen a `computer_use` call drives.
  final Widget? preview;

  /// The approvals that hold up a call, by its position in [calls].
  final Map<int, ApprovalRequest> approvals;

  /// Sends the answer to one of [approvals].
  final Future<void> Function(String requestId, String choice)?
  onAnswerApproval;

  /// Where what the reader opened is kept beyond this widget; this widget's
  /// own state when null.
  final ToolCallExpansionStore? expansion;

  /// Tells this run from the others in [expansion]: the id of its message.
  final String expansionScope;

  @override
  State<ToolCallGroup> createState() => _ToolCallGroupState();
}

class _ToolCallGroupState extends State<ToolCallGroup> {
  final _local = ToolCallExpansionStore();

  ToolCallExpansionStore get _store => widget.expansion ?? _local;

  String get _scope => widget.expansionScope;

  bool get _open => _store.groupOpen(_scope);

  /// The key of a card: the call's id, or its place in the run for a call the
  /// server sent no id for.
  static String _key(List<ToolCall> calls, int i) =>
      calls[i].id.isNotEmpty ? 'id:${calls[i].id}' : 'at:$i';

  String _keyOf(int i) => _key(widget.calls, i);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ToolCallGroup old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Brings the store in line with the calls, whether they just arrived or
  /// this widget was built anew with them: a call that was still being written
  /// has no id until it starts, so its card keeps its state under the new key;
  /// and the card of a lone call the reader opened opens the group that forms
  /// around it. Calls only ever append.
  void _sync() {
    final calls = widget.calls;
    for (var i = 0; i < calls.length; i++) {
      if (calls[i].id.isNotEmpty) {
        _store.moveCard(_scope, 'at:$i', _keyOf(i));
      }
    }
    if (calls.length > 1 && _store.takeLoneOpened(_scope)) {
      _store.setGroupOpen(_scope, true);
    }
    _store.retainCards(_scope, {
      for (var i = 0; i < calls.length; i++) _keyOf(i),
    });
  }

  /// What the last build made, and what it was made from. A parent that
  /// rebuilds while a reply streams hands this widget the same calls and
  /// approvals over and over; the pieces are returned as they were, so Flutter
  /// skips them and an open card's body is not laid out again.
  ///
  /// It is valid only while everything the pieces were made from is the same:
  /// the calls and approvals (each element identical), whether a callback is
  /// given, the store, the scope and whether the group is open. A toggle
  /// clears it. What comes from the [BuildContext] (theme, platform, text
  /// scale, locale, width) is read below the pieces, in a [Builder] and in the
  /// cards, so it still reaches them as an inherited dependency.
  _Pieces? _pieces;

  /// What a card calls to answer an approval. It goes through this method, not
  /// through the closure the parent last passed, so a card kept from an
  /// earlier build reaches the newest callback.
  Future<void> _answer(String requestId, String choice) =>
      widget.onAnswerApproval?.call(requestId, choice) ?? Future.value();

  _Pieces _piecesFor(bool open) {
    final held = _pieces;
    if (held != null && held.matches(widget, _store, open)) return held;
    return _pieces = _make(open);
  }

  _Pieces _make(bool open) {
    final calls = widget.calls;
    final answers = widget.onAnswerApproval != null;
    Widget card(int i) {
      final approval = widget.approvals[i];
      return ToolCallCard(
        call: calls[i],
        initiallyOpen: _store.cardOpen(_scope, _keyOf(i)),
        onOpenChanged: (open) {
          _store.setCardOpen(_scope, _keyOf(i), open);
          if (widget.calls.length == 1) _store.setLoneOpened(_scope, open);
        },
        approval: approval,
        onAnswerApproval: approval == null || !answers
            ? null
            : (choice) => _answer(approval.requestId, choice),
      );
    }

    Widget? header;
    Widget? cards;
    if (calls.length == 1) {
      cards = card(0);
    } else {
      final waiting = widget.approvals.entries
          .where((e) => e.value.status == InputRequestStatus.pending)
          .map((e) => calls[e.key]);
      final running = calls.where((c) => c.status == ToolCallStatus.running);
      final status = running.isNotEmpty
          ? ToolCallStatus.running
          : calls.any((c) => c.status == ToolCallStatus.error)
          ? ToolCallStatus.error
          : calls.every((c) => c.status == ToolCallStatus.cancelled)
          ? ToolCallStatus.cancelled
          : ToolCallStatus.completed;
      // Calls run in order, so the one running is the first that started; the
      // rest are still being written.
      final started = running.where((c) => !c.preparing);
      final label = waiting.isNotEmpty
          ? 'Waiting on ${waiting.first.displayName}'
          : started.isNotEmpty
          ? 'Running ${started.first.displayName}…'
          : running.isNotEmpty
          ? 'Preparing ${running.first.displayName}…'
          : 'Used ${calls.length} tools';
      final isWaiting = waiting.isNotEmpty;
      final showsOpen = open || isWaiting;
      final warns = calls.any((call) => call.outputRisk != null);
      header = Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          final subtle = context.hermesColors.subtleText;
          final minTap = platformChromeOf(context) == PlatformChrome.ios
              ? kAppleMinTapTarget
              : 0.0;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            // Hugs its text and nothing clips it: the ring goes outside.
            child: FocusRing.outside(
              radius: 8,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  DisclosureToggledNotification.send(context);
                  setState(() {
                    _pieces = null;
                    _store.setGroupOpen(_scope, !_open);
                  });
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minTap),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ToolCallStatusIcon(
                            status: status,
                            waiting: isWaiting,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              wellFormedText(label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          if (warns)
                            Tooltip(
                              message: 'Tool output warning',
                              child: AppIcon(
                                AppIcons.warning,
                                size: 16,
                                color: scheme.error,
                              ),
                            ),
                          AppIcon(
                            showsOpen
                                ? AppIcons.expandLess
                                : AppIcons.chevronRight,
                            size: 16,
                            color: subtle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (showsOpen) {
        // Keyed, with the preview below, so the cards keep their state (the
        // ones the reader opened) when the preview comes or goes and they
        // would otherwise move to another slot of the column and mount anew.
        cards = Padding(
          key: _cardsKey,
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, _) in calls.indexed) ...[
                card(i),
                const SizedBox(height: 6),
              ],
            ],
          ),
        );
      }
    }
    return _Pieces(
      calls: List.of(calls),
      approvals: Map.of(widget.approvals),
      answers: answers,
      store: _store,
      scope: _scope,
      open: open,
      header: header,
      cards: cards,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pieces = _piecesFor(_open);
    final preview = widget.preview;
    // Both shapes keep the preview in the child list's second place, which
    // with its key is all it takes for it to move without losing its state.
    if (widget.calls.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pieces.cards!,
          if (preview != null)
            Padding(padding: const EdgeInsets.only(top: 6), child: preview),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pieces.header!,
        if (preview != null)
          Padding(
            key: _previewKey,
            padding: const EdgeInsets.only(left: 2, top: 2),
            child: SizedBox(width: double.infinity, child: preview),
          ),
        ?pieces.cards,
      ],
    );
  }
}

const _cardsKey = ValueKey('tool-group-cards');
const _previewKey = ValueKey('tool-group-preview');

/// The widgets one build of [_ToolCallGroupState] made, with the inputs they
/// were made from. The preview is not one of them: the parent hands it in anew
/// each build, and it is placed around these.
class _Pieces {
  const _Pieces({
    required this.calls,
    required this.approvals,
    required this.answers,
    required this.store,
    required this.scope,
    required this.open,
    required this.header,
    required this.cards,
  });

  final List<ToolCall> calls;
  final Map<int, ApprovalRequest> approvals;
  final bool answers;
  final ToolCallExpansionStore store;
  final String scope;
  final bool open;
  final Widget? header;
  final Widget? cards;

  bool matches(ToolCallGroup widget, ToolCallExpansionStore store, bool open) {
    if (!identical(this.store, store) ||
        scope != widget.expansionScope ||
        this.open != open ||
        answers != (widget.onAnswerApproval != null) ||
        calls.length != widget.calls.length ||
        approvals.length != widget.approvals.length) {
      return false;
    }
    for (var i = 0; i < calls.length; i++) {
      if (!identical(calls[i], widget.calls[i])) return false;
    }
    for (final e in approvals.entries) {
      if (!identical(e.value, widget.approvals[e.key])) return false;
    }
    return true;
  }
}
