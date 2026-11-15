import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';

/// "Connection lost. Reconnecting…" under a reply whose connection dropped
/// while Hermes may still be working on it. It is not an error: the reply keeps
/// its text and its running tool calls, and the note goes when the connection
/// is back. An icon and the sentence say it, never colour alone, and the
/// sentence wraps at any text size.
///
/// [announceKey] says which loss this is. A screen reader is told once per key
/// for the life of the app, however often the row is built again (a list
/// builds and drops its rows as they scroll); null never announces, as in the
/// catalog.
class ReplyReconnectingNote extends StatefulWidget {
  const ReplyReconnectingNote({
    super.key,
    required this.text,
    this.announceKey,
  });

  final String text;
  final String? announceKey;

  /// The keys already announced.
  static final _announced = <String>{};

  @visibleForTesting
  static void forgetAnnouncements() => _announced.clear();

  @override
  State<ReplyReconnectingNote> createState() => _ReplyReconnectingNoteState();
}

class _ReplyReconnectingNoteState extends State<ReplyReconnectingNote> {
  @override
  void initState() {
    super.initState();
    _announce();
  }

  /// The row is kept by the list while its sentence changes (the tries ran
  /// out), so a new key announces here as well.
  @override
  void didUpdateWidget(ReplyReconnectingNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announceKey != widget.announceKey) _announce();
  }

  void _announce() {
    final key = widget.announceKey;
    if (key == null || !ReplyReconnectingNote._announced.add(key)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          widget.text,
          Directionality.of(context),
        ).catchError((Object _) {}),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = context.hermesColors.warning;
    return Semantics(
      container: true,
      label: widget.text,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AppIcon(AppIcons.wifiOff, size: 16, color: color),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.text,
                  style: TextStyle(color: color, fontSize: 13.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
