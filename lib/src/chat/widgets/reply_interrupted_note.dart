import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';

/// What is true of a reply the server no longer has, under whatever text it
/// kept: "Hermes restarted. This reply was interrupted.", "This reply is no
/// longer on the server.", or, when the server could not be made to say, that
/// the end could not be confirmed. It is not an error message of the app's own
/// and has no "try again" in it: an icon and the sentence say it, never colour
/// alone, and the sentence wraps at any text size.
///
/// [unconfirmed] picks the icon: a question mark for an ending nobody could
/// confirm, a stop mark for a turn the server says is over.
///
/// [announceKey] says which reply this is. A screen reader is told once per key
/// for the life of the app, however often the row is built again; null never
/// announces, as in the catalog.
class ReplyInterruptedNote extends StatefulWidget {
  const ReplyInterruptedNote({
    super.key,
    required this.text,
    this.unconfirmed = false,
    this.announceKey,
  });

  final String text;
  final bool unconfirmed;
  final String? announceKey;

  /// The keys already announced.
  static final _announced = <String>{};

  @visibleForTesting
  static void forgetAnnouncements() => _announced.clear();

  @override
  State<ReplyInterruptedNote> createState() => _ReplyInterruptedNoteState();
}

class _ReplyInterruptedNoteState extends State<ReplyInterruptedNote> {
  @override
  void initState() {
    super.initState();
    final key = widget.announceKey;
    if (key == null || !ReplyInterruptedNote._announced.add(key)) return;
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
                child: AppIcon(
                  widget.unconfirmed ? AppIcons.info : AppIcons.stop,
                  size: 16,
                  color: color,
                ),
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
