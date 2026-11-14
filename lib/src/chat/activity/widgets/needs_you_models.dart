import 'package:flutter/foundation.dart' show ValueChanged;

/// What kind of request waits on the user. `reclaim` and `resume` share the
/// Reopen action and differ in title and body.
enum NeedsYouKind { billing, connector, reclaim, resume }

/// Where the answer to an item stands. Only a connector answer goes through
/// `sending`; the other kinds stay `idle`.
enum NeedsYouAnswer { idle, sending, unconfirmed, refused }

/// An action an item offers. Whether it can run now follows from the item's
/// answer state and its offline flag.
enum NeedsYouAction { open, copy, skip, continueOn, reopen }

/// How one connector target stands.
enum ConnectorTargetStatus { waiting, signedIn, failed }

/// What an item shows in its scrolling body.
sealed class NeedsYouBodyModel {
  const NeedsYouBodyModel();
}

/// Billing step-up details. The [code] is never logged or stored.
class BillingBodyModel extends NeedsYouBodyModel {
  const BillingBodyModel({
    required this.code,
    required this.host,
    required this.openable,
  });

  final String code;

  /// The host the verification page lives on; null when the link is not a
  /// safe HTTPS address, so the page cannot be opened here.
  final String? host;

  /// Whether Open verification page can run.
  final bool openable;
}

/// One service a connector operation asks the user to sign in to.
class ConnectorTargetModel {
  const ConnectorTargetModel({
    required this.name,
    required this.status,
    this.detail,
    this.openable = false,
    this.skippable = false,
  });

  /// Server text, shown as it comes.
  final String name;
  final ConnectorTargetStatus status;

  /// Server text, shown as it comes.
  final String? detail;
  final bool openable;

  /// Whether this target can be skipped.
  final bool skippable;
}

class ConnectorBodyModel extends NeedsYouBodyModel {
  const ConnectorBodyModel({required this.targets, this.expiresIn});

  final List<ConnectorTargetModel> targets;

  /// Time left before the operation expires; null when it has no deadline.
  final Duration? expiresIn;
}

/// A reclaimed chat, or one whose restore failed.
class ReclaimBodyModel extends NeedsYouBodyModel {
  const ReclaimBodyModel({this.reason});

  /// Why the server says so; server text, shown as it comes.
  final String? reason;
}

/// One request in the dock.
class NeedsYouItem {
  const NeedsYouItem({
    required this.id,
    required this.kind,
    required this.body,
    this.answer = NeedsYouAnswer.idle,
    this.offline = false,
    this.actions = const {},
  });

  /// Stable across rebuilds; the queue's key for the item.
  final String id;
  final NeedsYouKind kind;
  final NeedsYouBodyModel body;
  final NeedsYouAnswer answer;

  /// The connection is lost: a connector or reclaim item stays as a display
  /// only card with its actions disabled. A billing item never is offline.
  final bool offline;
  final Set<NeedsYouAction> actions;
}

typedef NeedsYouItemCallback = void Function(NeedsYouItem item);

/// The dock's state and what its controls do.
class NeedsYouDockModel {
  const NeedsYouDockModel({
    required this.items,
    this.shown = 0,
    this.compact = false,
    this.onShow,
    this.onCopy,
    this.onOpen,
    this.onSkip,
    this.onContinue,
    this.onReopen,
  });

  /// Oldest first.
  final List<NeedsYouItem> items;

  /// The index of the item on the card.
  final int shown;

  /// Collapses the card to its title, one summary line and its actions, for
  /// a keyboard that leaves the chat little room (see
  /// [needsYouCompactFor]).
  final bool compact;

  /// Pages to another item.
  final ValueChanged<int>? onShow;
  final NeedsYouItemCallback? onCopy;

  /// Opens the browser; [target] names the connector target, null for a
  /// billing page or the only target.
  final void Function(NeedsYouItem item, String? target)? onOpen;
  final NeedsYouItemCallback? onContinue, onReopen;

  /// Skips [target], a connector target.
  final void Function(NeedsYouItem item, String target)? onSkip;
}
