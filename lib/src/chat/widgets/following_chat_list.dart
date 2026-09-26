import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show ChatItem;
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show ChatAnimatedList, InitialScrollToEndMode;

/// A [ChatAnimatedList] that stays at the bottom while its content grows,
/// until the reader scrolls up, and follows again once they are back.
///
/// The package only scrolls when a message is inserted, not when one grows,
/// so a streaming reply ran off the bottom. Its scroll-to-bottom button then
/// took the gap for the reader having scrolled away and stopped following
/// inserts too. And its jump to the end on open stayed armed while a reply
/// kept growing a thread that had fit the screen, pulling a reader who
/// scrolled up back down; following covers the open as well.
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
  var _following = true;
  var _dragging = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _onNotification(Notification notification) {
    // Code blocks and tool output scroll on their own; only the list counts.
    if (notification is ViewportNotificationMixin && notification.depth > 0) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _dragging = notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
    }
    if (notification is ScrollUpdateNotification) {
      final metrics = notification.metrics;
      if (metrics.maxScrollExtent - metrics.pixels <= _slack) {
        _following = true;
      } else if ((notification.scrollDelta ?? 0) < 0) {
        _following = false;
      }
    } else if (notification is ScrollMetricsNotification &&
        _following &&
        !_dragging &&
        _scroll.hasClients) {
      // Past the end too: the list first jumps to an estimated end, and once
      // it lays out the real items the end can move up by screens. iOS would
      // bounce back from there slowly, ignoring taps all the while.
      final position = _scroll.position;
      if (position.pixels != position.maxScrollExtent) {
        position.jumpTo(position.maxScrollExtent);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: ChatAnimatedList(
        itemBuilder: widget.itemBuilder,
        scrollController: _scroll,
        onEndReached: widget.onEndReached,
        initialScrollToEndMode: InitialScrollToEndMode.none,
        shouldScrollToEndWhenAtBottom: false,
      ),
    );
  }
}
