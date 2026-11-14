import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../theme/platform_chrome.dart';
import '../../../widgets/busy_bar.dart';
import '../../../widgets/named_icon_button.dart';
import '../../widgets/chat_builders.dart' show kChatColumnMaxWidth;
import 'needs_you_bodies.dart';
import 'needs_you_models.dart';

/// The chat height left above the keyboard below which the card collapses
/// while the keyboard is open. A 667 pt phone with the keyboard up has about
/// 400 pt left and collapses; an iPhone 15 (844 pt) has about 510 and
/// collapses too; a tablet or a desktop window never does.
const double kNeedsYouCompactHeight = 560;

/// Whether the dock should collapse for [media]: the keyboard is open and
/// leaves less than [kNeedsYouCompactHeight].
bool needsYouCompactFor(MediaQueryData media) =>
    media.viewInsets.bottom > 0 &&
    media.size.height - media.viewInsets.bottom < kNeedsYouCompactHeight;

/// Builds the dock for the composer's box: [compact] says whether the
/// keyboard leaves the chat so little room that the card collapses.
typedef NeedsYouDockBuilder = Widget Function(
  BuildContext context,
  bool compact,
);

/// Below this card width the billing actions stack, full width.
const double _kStackActionsWidth = 480;

/// The body takes at most this share of the height the chat has left.
const double _kBodyShare = 0.4;

/// Below this card width the paging controls take their own row under the
/// title, so the title keeps the full width (two lines at most).
const double _kNarrowCardWidth = 400;

/// Whether the paging controls sit under the title rather than beside it.
bool _stackPaging(BuildContext context, {required bool narrow}) =>
    narrow || MediaQuery.textScalerOf(context).scale(1) >= 1.3;

/// A card above the composer that holds what the agent needs from the user,
/// one request at a time, oldest first.
///
/// A plain-model widget: the bound layer maps controllers to a
/// [NeedsYouDockModel]. Only the body scrolls, so the title and the actions
/// stay visible with the keyboard open.
class NeedsYouDock extends StatelessWidget {
  const NeedsYouDock({super.key, required this.model});

  final NeedsYouDockModel model;

  @override
  Widget build(BuildContext context) {
    final items = model.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final index = model.shown.clamp(0, items.length - 1);
    final item = items[index];
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kChatColumnMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: context.l10n.chatActivityNeedsYouDockLabel(items.length),
            child: Material(
              key: const Key('needs-you-dock'),
              color: scheme.surfaceContainerHighest,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kHermesRadius),
                side: BorderSide(color: scheme.outline),
              ),
              child: LayoutBuilder(
                builder: (context, box) => _Card(
                  model: model,
                  item: item,
                  index: index,
                  stackActions: box.maxWidth < _kStackActionsWidth,
                  narrow: box.maxWidth < _kNarrowCardWidth,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.model,
    required this.item,
    required this.index,
    required this.stackActions,
    required this.narrow,
  });

  final NeedsYouDockModel model;
  final NeedsYouItem item;
  final int index;
  final bool stackActions, narrow;

  bool get _offline => item.offline && item.kind != NeedsYouKind.billing;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final l10n = context.l10n;
    final sending = item.answer == NeedsYouAnswer.sending;
    final notice = _noticeText(l10n);
    return LayoutBuilder(
      builder: (context, box) {
        final left = box.hasBoundedHeight
            ? box.maxHeight
            : media.size.height - media.viewInsets.bottom - media.padding.top;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(model: model, item: item, index: index, narrow: narrow),
            if (sending) const BusyBar(minHeight: 2),
            _flexible(
              bounded: box.hasBoundedHeight,
              child: model.compact
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _Summary(item: item),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: left * _kBodyShare,
                      ),
                      child: _ScrollingBody(
                        key: const Key('needs-you-body'),
                        child: _Body(
                          model: model,
                          item: item,
                          offline: _offline,
                        ),
                      ),
                    ),
            ),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: sending
                    ? Text(
                        notice,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: context.hermesColors.subtleText),
                      )
                    : NeedsYouNoticeLine(text: notice),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: _Actions(
                model: model,
                item: item,
                offline: _offline,
                stack: stackActions,
              ),
            ),
          ],
        );
      },
    );
  }

  String? _noticeText(AppLocalizations l10n) {
    if (_offline) return l10n.chatActivityNeedsYouOfflineNotice;
    return switch (item.answer) {
      NeedsYouAnswer.idle => null,
      NeedsYouAnswer.sending => l10n.chatActivityNeedsYouSendingNotice,
      NeedsYouAnswer.unconfirmed => l10n.chatActivityNeedsYouUnconfirmedNotice,
      NeedsYouAnswer.refused => l10n.chatActivityNeedsYouRefusedNotice,
    };
  }
}

/// [Flexible] only inside a bounded column, where it may shrink the body.
Widget _flexible({required bool bounded, required Widget child}) =>
    bounded ? Flexible(child: child) : child;

String _title(AppLocalizations l10n, NeedsYouItem item) => switch (item.kind) {
  NeedsYouKind.billing => l10n.chatActivityNeedsYouBillingTitle,
  NeedsYouKind.reclaim => l10n.chatActivityNeedsYouReclaimTitle,
  NeedsYouKind.resume => l10n.chatActivityNeedsYouResumeTitle,
  NeedsYouKind.connector => switch (item.body) {
    ConnectorBodyModel(targets: [final only]) =>
      l10n.chatActivityNeedsYouConnectTitle(only.name),
    ConnectorBodyModel(:final targets) =>
      l10n.chatActivityNeedsYouConnectManyTitle(targets.length),
    _ => () {
      assert(false, 'A connector item carries a ConnectorBodyModel.');
      return '';
    }(),
  },
};

AppIconSet _icon(NeedsYouKind kind) => switch (kind) {
  NeedsYouKind.billing => AppIcons.billing,
  NeedsYouKind.connector => AppIcons.link,
  NeedsYouKind.reclaim => AppIcons.swap,
  NeedsYouKind.resume => AppIcons.warning,
};

class _Header extends StatelessWidget {
  const _Header({
    required this.model,
    required this.item,
    required this.index,
    required this.narrow,
  });

  final NeedsYouDockModel model;
  final NeedsYouItem item;
  final int index;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = model.items.length;
    final chrome = platformChromeOf(context);
    final size = switch (chrome) {
      PlatformChrome.macos => 28.0,
      PlatformChrome.ios => 44.0,
      PlatformChrome.material => 48.0,
    };
    final style = IconButton.styleFrom(
      fixedSize: Size.square(size),
      minimumSize: Size.square(size),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final onShow = model.onShow;
    // Beside the title the paging controls leave it three or four lines on a
    // phone or at a large text size, so they take their own row there.
    final stackPaging = _stackPaging(context, narrow: narrow);
    final paging = [
      Flexible(
        child: Text(
          l10n.chatActivityNeedsYouPosition(index + 1, count),
          textAlign: TextAlign.end,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.hermesColors.subtleText),
        ),
      ),
      NamedIconButton(
        key: const Key('needs-you-previous'),
        label: l10n.chatActivityNeedsYouPrevious,
        icon: AppIcons.chevronLeft,
        style: style,
        onPressed: index > 0 && onShow != null ? () => onShow(index - 1) : null,
      ),
      NamedIconButton(
        key: const Key('needs-you-next'),
        label: l10n.chatActivityNeedsYouNext,
        icon: AppIcons.chevronRight,
        style: style,
        onPressed: index < count - 1 && onShow != null
            ? () => onShow(index + 1)
            : null,
      ),
    ];
    final title = Row(
      crossAxisAlignment: count > 1 && !stackPaging
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (!needsYouLargeText(context)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AppIcon(
              _icon(item.kind),
              size: needsYouIconSize(context, 20),
              color: context.hermesColors.warning,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              _title(l10n, item),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (count > 1 && !stackPaging) ...[const SizedBox(width: 8), ...paging],
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        count > 1 && !stackPaging ? 4 : 14,
        count > 1 && !stackPaging ? 8 : 16,
        6,
      ),
      child: count > 1 && stackPaging
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                Row(mainAxisAlignment: MainAxisAlignment.end, children: paging),
              ],
            )
          : title,
    );
  }
}

/// Whether more than one target of a connector item has its own Open.
bool _perTargetSkip(NeedsYouItem item) =>
    item.actions.contains(NeedsYouAction.skip) &&
    item.body is ConnectorBodyModel &&
    (item.body as ConnectorBodyModel).targets.where((t) => t.skippable).length >
        1;

bool _perTargetOpen(NeedsYouItem item) =>
    item.actions.contains(NeedsYouAction.open) &&
    item.body is ConnectorBodyModel &&
    (item.body as ConnectorBodyModel).targets.where((t) => t.openable).length >
        1;

class _Body extends StatelessWidget {
  const _Body({required this.model, required this.item, required this.offline});

  final NeedsYouDockModel model;
  final NeedsYouItem item;
  final bool offline;

  @override
  Widget build(BuildContext context) => switch (item.body) {
    BillingBodyModel body => BillingNeedsYouBody(model: body),
    ConnectorBodyModel body => ConnectorNeedsYouBody(
      model: body,
      onOpen: _perTargetOpen(item) && model.onOpen != null
          ? (target) => model.onOpen!(item, target)
          : null,
      openEnabled: !offline && item.actions.contains(NeedsYouAction.open),
      onSkip: _perTargetSkip(item) && model.onSkip != null
          ? (target) => model.onSkip!(item, target)
          : null,
      skipEnabled: !offline && item.answer != NeedsYouAnswer.sending,
    ),
    ReclaimBodyModel body => ReclaimNeedsYouBody(
      model: body,
      restoreFailed: item.kind == NeedsYouKind.resume,
    ),
  };
}

/// The collapsed body: one line saying what waits.
class _Summary extends StatelessWidget {
  const _Summary({required this.item});

  final NeedsYouItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final text = switch (item.body) {
      BillingBodyModel(:final host) =>
        host == null
            ? l10n.chatActivityNeedsYouLinkUnavailable
            : l10n.chatActivityNeedsYouOpensHost(host),
      ConnectorBodyModel body => [
        _connectorSummary(l10n, body),
        if (body.expiresIn case final left?) needsYouExpiresText(context, left),
      ].join(' · '),
      ReclaimBodyModel() =>
        item.kind == NeedsYouKind.resume
            ? l10n.chatActivityNeedsYouResumeBody
            : l10n.chatActivityNeedsYouReclaimBody,
    };
    return Text(
      text,
      key: const Key('needs-you-summary'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subtle),
    );
  }

  String _connectorSummary(AppLocalizations l10n, ConnectorBodyModel body) {
    final waiting = body.targets
        .where((t) => t.status == ConnectorTargetStatus.waiting)
        .length;
    if (waiting > 1) return l10n.chatActivityNeedsYouSignInsWaiting(waiting);
    final first = body.targets.firstOrNull;
    return switch (first?.status) {
      null => '',
      ConnectorTargetStatus.waiting => l10n.chatActivityNeedsYouTargetWaiting,
      ConnectorTargetStatus.signedIn => l10n.chatActivityNeedsYouTargetSignedIn,
      ConnectorTargetStatus.failed => l10n.chatActivityNeedsYouTargetFailed,
    };
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.model,
    required this.item,
    required this.offline,
    required this.stack,
  });

  final NeedsYouDockModel model;
  final NeedsYouItem item;
  final bool offline;
  final bool stack;

  bool _has(NeedsYouAction action) => item.actions.contains(action);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sending = item.answer == NeedsYouAnswer.sending;
    VoidCallback? run(NeedsYouItemCallback? callback, {bool enabled = true}) =>
        callback == null || offline || !enabled ? null : () => callback(item);

    final buttons = <Widget>[];
    switch (item.kind) {
      case NeedsYouKind.billing:
        final openable =
            item.body is BillingBodyModel &&
            (item.body as BillingBodyModel).openable;
        final open = FilledButton(
          key: const Key('needs-you-open'),
          onPressed:
              _has(NeedsYouAction.open) && openable && model.onOpen != null
              ? () => model.onOpen!(item, null)
              : null,
          child: Text(l10n.chatActivityNeedsYouBillingOpen),
        );
        final copy = OutlinedButton(
          style: needsYouOutlinedStyle(context),
          key: const Key('needs-you-copy'),
          onPressed: _has(NeedsYouAction.copy) ? run(model.onCopy) : null,
          child: Text(l10n.chatActivityNeedsYouBillingCopy),
        );
        buttons.addAll(stack ? [open, copy] : [copy, open]);
      case NeedsYouKind.connector:
        final targets = item.body is ConnectorBodyModel
            ? (item.body as ConnectorBodyModel).targets
            : const <ConnectorTargetModel>[];
        final single = targets.where((t) => t.openable).toList();
        // Several targets have their own Open in the body; the collapsed card
        // has no body, so its row keeps one Open for the first waiting target.
        final showOpen =
            _has(NeedsYouAction.open) &&
            single.isNotEmpty &&
            (single.length == 1 || model.compact);
        final openTarget = single.isEmpty
            ? null
            : single.firstWhere(
                (t) => t.status == ConnectorTargetStatus.waiting,
                orElse: () => single.first,
              );
        final hasOpen = showOpen;
        // One Skip per target: in the body when several can be skipped, in
        // this row when exactly one can.
        final skippable = targets.where((t) => t.skippable).toList();
        if (_has(NeedsYouAction.skip) && skippable.length == 1) {
          buttons.add(
            TextButton(
              key: const Key('needs-you-skip'),
              onPressed: offline || sending || model.onSkip == null
                  ? null
                  : () => model.onSkip!(item, skippable.single.name),
              child: Text(l10n.chatActivityNeedsYouConnectorSkip),
            ),
          );
        }
        if (_has(NeedsYouAction.continueOn)) {
          final onPressed = run(model.onContinue, enabled: !sending);
          buttons.add(
            hasOpen
                ? OutlinedButton(
                    style: needsYouOutlinedStyle(context),
                    key: const Key('needs-you-continue'),
                    onPressed: onPressed,
                    child: Text(l10n.chatActivityNeedsYouConnectorContinue),
                  )
                : FilledButton(
                    key: const Key('needs-you-continue'),
                    onPressed: onPressed,
                    child: Text(l10n.chatActivityNeedsYouConnectorContinue),
                  ),
          );
        }
        if (showOpen) {
          buttons.add(
            FilledButton(
              key: const Key('needs-you-open'),
              onPressed: offline || model.onOpen == null
                  ? null
                  : () => model.onOpen!(item, openTarget?.name),
              child: Text(l10n.chatActivityNeedsYouConnectorOpen),
            ),
          );
        }
      case NeedsYouKind.reclaim:
      case NeedsYouKind.resume:
        if (_has(NeedsYouAction.reopen)) {
          buttons.add(
            FilledButton(
              key: const Key('needs-you-reopen'),
              onPressed: run(model.onReopen),
              child: Text(l10n.chatActivityNeedsYouReopen),
            ),
          );
        }
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    if (stack && item.kind == NeedsYouKind.billing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, b) in buttons.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            b,
          ],
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }
}

/// The card's body: scrolls, and shows that it does. A scrollbar stays up while
/// there is more than fits, and a fade at the bottom edge says there is more
/// below, so a row cut off by the height cap does not read as the end.
class _ScrollingBody extends StatefulWidget {
  const _ScrollingBody({super.key, required this.child});

  final Widget child;

  @override
  State<_ScrollingBody> createState() => _ScrollingBodyState();
}

class _ScrollingBodyState extends State<_ScrollingBody> {
  final _controller = ScrollController();
  bool _scrollable = false, _more = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _update(ScrollMetrics m) {
    final scrollable = m.maxScrollExtent > 0.5;
    final more = m.maxScrollExtent - m.pixels > 1;
    if (scrollable != _scrollable || more != _more) {
      setState(() {
        _scrollable = scrollable;
        _more = more;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final card = Theme.of(context).colorScheme.surfaceContainerHighest;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _update(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _update(n.metrics),
        child: Stack(
          children: [
            Scrollbar(
              controller: _controller,
              thumbVisibility: _scrollable,
              child: SingleChildScrollView(
                controller: _controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: widget.child,
              ),
            ),
            if (_more)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [card.withValues(alpha: 0), card],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
