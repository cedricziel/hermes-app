import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show ChatItem;
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ChatAnimatedList, InitialScrollToEndMode;

import 'blank_list_watchdog.dart';

/// A [ChatAnimatedList] that stays at the bottom while its content grows,
/// until the reader scrolls up, and follows again once they are back.
///
/// The package only scrolls when a message is inserted, not when one grows,
/// so a streaming reply ran off the bottom. Its scroll-to-bottom button then
/// took the gap for the reader having scrolled away and stopped following
/// inserts too. And its jump to the end on open stayed armed while a reply
/// kept growing a thread that had fit the screen, pulling a reader who
/// scrolled up back down; following covers the open as well.
///
/// Items appear and disappear without animating. An item still animating out
/// keeps a stale index in `SliverAnimatedList`, because the package's index
/// lookup no longer finds its message. Later inserts and removals then reorder
/// the sliver's children, and paint fails a null check in
/// `childMainAxisPosition`. Inserts take no time either, because an item
/// removed while it animates in keeps its insert duration.
///
/// While following a streaming reply it also arms [BlankListWatchdog]: if the
/// list churns its metrics but paints no items, it has lost its sliver state
/// (the blank-thread bug) and one remount recovers it, without losing any
/// message — they live in the controller above.
class FollowingChatList extends StatefulWidget {
  const FollowingChatList({
    super.key,
    required this.itemBuilder,
    this.onEndReached,
  });

  final ChatItem itemBuilder;
  final Future<void> Function()? onEndReached;

  @override
  State<FollowingChatList> createState() => _FollowingChatListState();
}

class _FollowingChatListState extends State<FollowingChatList> {
  /// How far above the bottom still counts as being there.
  static const _slack = 24.0;

  final _scroll = ScrollController();
  final _watchdog = BlankListWatchdog();
  var _following = true;
  var _dragging = false;

  /// Bumped when the watchdog recovers: remounts the list under a fresh key.
  var _generation = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  ChatItem get _countingItemBuilder =>
      (
        context,
        message,
        index,
        animation, {
        messagesGroupingMode,
        messageGroupingTimeoutInSeconds,
        isRemoved,
      }) {
        _watchdog.onItemBuilt();
        return widget.itemBuilder(
          context,
          message,
          index,
          animation,
          messagesGroupingMode: messagesGroupingMode,
          messageGroupingTimeoutInSeconds: messageGroupingTimeoutInSeconds,
          isRemoved: isRemoved,
        );
      };

  bool _onNotification(Notification notification) {
    // Code blocks and tool output scroll on their own; only the list counts.
    if (notification is ViewportNotificationMixin && notification.depth > 0) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _dragging = notification.dragDetails != null;
      if (_dragging) _watchdog.disarm();
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
      // Whatever grew during the drag went unfollowed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _catchUp();
      });
      WidgetsBinding.instance.scheduleFrame();
    }
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      if (metrics.maxScrollExtent - metrics.pixels <= _slack) {
        _following = true;
      } else if ((notification.scrollDelta ?? 0) < 0) {
        _following = false;
        _watchdog.disarm();
      }
    } else if (notification is ScrollMetricsNotification) {
      _catchUp();
    }
    return false;
  }

  void _catchUp() {
    if (!_following || _dragging || !_scroll.hasClients) return;
    // Past the end too: the list first jumps to an estimated end, and once
    // it lays out the real items the end can move up by screens. iOS would
    // bounce back from there slowly, ignoring taps all the while.
    final position = _scroll.position;
    if (position.pixels != position.maxScrollExtent) {
      position.jumpTo(position.maxScrollExtent);
    }
    // Following at the end of a non-empty list whose metrics churn (a reply
    // is streaming): every such step without an item build counts against
    // the blank-thread state. An empty list has no items to paint, so it
    // never arms the watchdog.
    if (position.maxScrollExtent > 0 && _watchdog.onFollowingStep()) {
      _recover();
    }
  }

  void _recover() {
    if (!mounted) return;
    setState(() => _generation++);
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: KeyedSubtree(
        key: ValueKey(_generation),
        child: ChatAnimatedList(
          itemBuilder: _countingItemBuilder,
          scrollController: _scroll,
          onEndReached: widget.onEndReached,
          initialScrollToEndMode: InitialScrollToEndMode.none,
          shouldScrollToEndWhenAtBottom: false,
          insertAnimationDuration: Duration.zero,
          removeAnimationDuration: Duration.zero,
        ),
      ),
    );
  }
}
