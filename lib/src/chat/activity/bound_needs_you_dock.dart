import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../l10n/l10n.dart';
import '../../telemetry/breadcrumbs.dart';
import '../billing_verification_controller.dart';
import '../chat_controller.dart';
import '../chat_models.dart';
import '../connector_operation_controller.dart';
import '../connector_operation_state.dart';
import 'needs_you_queue.dart';
import 'widgets/needs_you_dock.dart';
import 'widgets/needs_you_models.dart';

/// What the queue reads for the chat [chat] shows: its billing details, its
/// session's connector operations and its session state.
NeedsYouSources needsYouSources(ChatController chat) {
  final thread = chat.selectedThread;
  if (thread == null) {
    return (scope: null, billing: null, connector: null, session: null);
  }
  return (
    scope: (chat.profile, thread.id),
    billing: chat.billingVerificationIn(thread),
    connector: chat.connectorOperationsIn(thread),
    session: chat.sessionStateIn(thread),
  );
}

/// A [NeedsYouQueue] for the chat [chat] shows. The screen that owns the
/// chat owns the queue and disposes it.
NeedsYouQueue needsYouQueueFor(
  ChatController chat, {
  Breadcrumbs breadcrumbs = Breadcrumbs.none,
  void Function(NeedsYouEntry entry)? onArrived,
}) => NeedsYouQueue(
  changes: chat,
  read: () => needsYouSources(chat),
  now: () => chat.clockNow,
  breadcrumbs: breadcrumbs,
  onArrived: onArrived,
);

/// Announces a request that reached the queue to assistive technology: a
/// fixed sentence for its kind, never its code, link, target names or the
/// server's reason.
void announceNeedsYou(BuildContext context, NeedsYouKind kind) {
  final l10n = context.l10n;
  final text = switch (kind) {
    NeedsYouKind.billing => l10n.chatActivityNeedsYouAnnounceBilling,
    NeedsYouKind.connector => l10n.chatActivityNeedsYouAnnounceConnector,
    NeedsYouKind.reclaim => l10n.chatActivityNeedsYouAnnounceReclaim,
    NeedsYouKind.resume => l10n.chatActivityNeedsYouAnnounceResume,
  };
  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      text,
      Directionality.of(context),
    ).catchError((Object _) {}),
  );
}

/// The dock of [queue]'s chat, bound to the controllers behind its items.
///
/// Rebuilds with the chat (every controller of a chat reports through it) and
/// with the queue, and once in a while so "Expires in 4 min" stays true.
class BoundNeedsYouDock extends StatefulWidget {
  const BoundNeedsYouDock({
    super.key,
    required this.chat,
    required this.queue,
    this.compact = false,
  });

  final ChatController chat;
  final NeedsYouQueue queue;
  final bool compact;

  @override
  State<BoundNeedsYouDock> createState() => _BoundNeedsYouDockState();
}

class _BoundNeedsYouDockState extends State<BoundNeedsYouDock> {
  Timer? _tick;

  void _keepTime(bool needed) {
    if (needed && _tick == null) {
      _tick = Timer.periodic(
        const Duration(seconds: 15),
        (_) => mounted ? setState(() {}) : null,
      );
    } else if (!needed) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.chat, widget.queue]),
    builder: (context, _) {
      final model = needsYouDockModel(
        widget.chat,
        widget.queue,
        compact: widget.compact,
      );
      _keepTime(
        model.items.any(
          (item) =>
              item.body is ConnectorBodyModel &&
              (item.body as ConnectorBodyModel).expiresIn != null,
        ),
      );
      return NeedsYouDock(model: model);
    },
  );
}

/// The model of the dock for [queue]'s items, read from [chat]'s controllers
/// now. Items whose source has gone are left out.
NeedsYouDockModel needsYouDockModel(
  ChatController chat,
  NeedsYouQueue queue, {
  bool compact = false,
}) {
  final thread = chat.selectedThread;
  final items = <NeedsYouItem>[];
  if (thread != null) {
    for (final entry in queue.entries) {
      final item = switch (entry.kind) {
        NeedsYouKind.billing => _billing(chat, thread, entry),
        NeedsYouKind.connector => _connector(chat, thread, entry),
        NeedsYouKind.reclaim ||
        NeedsYouKind.resume => _session(chat, thread, entry),
      };
      if (item != null) items.add(item);
    }
  }
  return NeedsYouDockModel(
    items: items,
    shown: items.isEmpty ? 0 : queue.shown.clamp(0, items.length - 1),
    compact: compact,
    onShow: queue.show,
    onCopy: (item) {
      final billing = chat.billingVerificationIn(thread!);
      final details = billing?.verification;
      if (billing == null || details == null) return;
      unawaited(
        billing.copyVerificationCode(
          expectedDetails: details,
          expectedGeneration: billing.generation,
        ),
      );
    },
    onOpen: (item, target) {
      if (item.kind == NeedsYouKind.billing) {
        final billing = chat.billingVerificationIn(thread!);
        final details = billing?.verification;
        if (billing == null || details == null) return;
        unawaited(
          billing.openVerification(
            expectedDetails: details,
            expectedGeneration: billing.generation,
          ),
        );
        return;
      }
      final found = _operation(chat, thread!, item.id);
      if (found == null) return;
      final (controller, operation) = found;
      final attachment = controller.attachment;
      final name =
          target ??
          operation.targets
              .where((t) => controller.offersOpen(operation.key, t.name))
              .firstOrNull
              ?.name;
      if (attachment == null || name == null) return;
      unawaited(controller.openTarget(operation, name, attachment: attachment));
    },
    onSkip: (item) {
      final found = _operation(chat, thread!, item.id);
      final attachment = found?.$1.attachment;
      if (found == null || attachment == null) return;
      unawaited(found.$1.skipAll(found.$2, attachment: attachment));
    },
    onContinue: (item) {
      final found = _operation(chat, thread!, item.id);
      final attachment = found?.$1.attachment;
      if (found == null || attachment == null) return;
      unawaited(found.$1.continueOperation(found.$2, attachment: attachment));
    },
    onReopen: (item) => chat.reopenSession(thread!),
  );
}

(ConnectorOperationController, ConnectorOperationSnapshot)? _operation(
  ChatController chat,
  ChatThread thread,
  String key,
) {
  final controller = chat.connectorOperationsIn(thread);
  if (controller == null) return null;
  for (final operation in controller.operations) {
    if (connectorEntryKey(operation) == key) return (controller, operation);
  }
  return null;
}

NeedsYouItem? _billing(
  ChatController chat,
  ChatThread thread,
  NeedsYouEntry entry,
) {
  final BillingVerificationController? billing = chat.billingVerificationIn(
    thread,
  );
  final details = billing?.verification;
  if (billing == null || details == null) return null;
  return NeedsYouItem(
    id: entry.key,
    kind: NeedsYouKind.billing,
    body: BillingBodyModel(
      code: details.userCode,
      host: details.browserUri?.host,
      openable: billing.canOpenVerification,
    ),
    actions: {
      NeedsYouAction.open,
      if (billing.canCopyCode) NeedsYouAction.copy,
    },
  );
}

NeedsYouItem? _connector(
  ChatController chat,
  ChatThread thread,
  NeedsYouEntry entry,
) {
  final found = _operation(chat, thread, entry.key);
  if (found == null) return null;
  final (controller, operation) = found;
  final key = operation.key;
  final left = operation.deadlineAt.difference(chat.clockNow);
  // Display-only: the actions are drawn, disabled, so the card does not
  // change shape and they come back with the reconnect.
  final offline = controller.displayOnly;
  return NeedsYouItem(
    id: entry.key,
    kind: NeedsYouKind.connector,
    body: ConnectorBodyModel(
      targets: [
        for (final target in operation.targets)
          if (target.state != 'skipped')
            ConnectorTargetModel(
              name: target.name,
              status: _status(target),
              detail: target.detail ?? target.instructions,
              openable: offline
                  ? _couldOpen(target)
                  : controller.offersOpen(key, target.name),
            ),
      ],
      expiresIn: left > Duration.zero ? left : null,
    ),
    answer: switch (controller.answerFor(key)) {
      ConnectorAnswer.idle => NeedsYouAnswer.idle,
      ConnectorAnswer.sending => NeedsYouAnswer.sending,
      ConnectorAnswer.unconfirmed => NeedsYouAnswer.unconfirmed,
      ConnectorAnswer.refused => NeedsYouAnswer.refused,
    },
    offline: offline,
    actions: offline
        ? {
            if (operation.targets.any(_couldOpen)) NeedsYouAction.open,
            if (operation.targets.any((t) => t.supportsSkip))
              NeedsYouAction.skip,
            NeedsYouAction.continueOn,
          }
        : {
            if (operation.targets.any(
              (t) => controller.offersOpen(key, t.name),
            ))
              NeedsYouAction.open,
            if (operation.targets.any(
              (t) => controller.offersSkip(key, t.name),
            ))
              NeedsYouAction.skip,
            if (controller.offersRespond(key)) NeedsYouAction.continueOn,
          },
  );
}

/// Whether a target would offer Open with its link, which a display-only
/// model no longer holds.
bool _couldOpen(ConnectorOperationTarget target) =>
    target.canCompleteHere &&
    const {'pending', 'initiated'}.contains(target.state);

ConnectorTargetStatus _status(ConnectorOperationTarget target) {
  if (target.resolved == true || target.state == 'connected') {
    return ConnectorTargetStatus.signedIn;
  }
  return switch (target.state) {
    'failed' || 'expired' => ConnectorTargetStatus.failed,
    _ => ConnectorTargetStatus.waiting,
  };
}

NeedsYouItem? _session(
  ChatController chat,
  ChatThread thread,
  NeedsYouEntry entry,
) {
  final state = chat.sessionStateIn(thread);
  if (state == null) return null;
  final reclaimed = entry.kind == NeedsYouKind.reclaim;
  final reason = reclaimed ? state.reclaimedReason : state.resume?.message;
  return NeedsYouItem(
    id: entry.key,
    kind: entry.kind,
    body: ReclaimBodyModel(
      reason: reason == null || reason.isEmpty ? null : reason,
    ),
    offline: chat.connectionLostFor(thread),
    actions: const {NeedsYouAction.reopen},
  );
}
