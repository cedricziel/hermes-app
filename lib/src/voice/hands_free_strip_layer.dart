import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'calls/active_call.dart';
import 'widgets/hands_free_strip.dart';

/// Puts the Hands-free strip above [child] on every screen of the main window
/// while a call's microphone is open, or after a call ended without
/// confirming that it closed.
///
/// It wraps the app's navigator, so a page pushed over the shell (settings,
/// a sheet's route) does not hide it. Only the main window builds this: a
/// macOS conversation window and the quick panel are separate engines with no
/// call and show none; the operating system's microphone indicator covers
/// them. Under App Lock the cover is drawn over this and keeps its own mark.
///
/// The strip carries End while the call screen is closed (the screen has its
/// own End). Without an [ActiveCallRegistry] it is just [child].
class HandsFreeStripLayer extends StatefulWidget {
  const HandsFreeStripLayer({super.key, required this.child});

  final Widget child;

  @override
  State<HandsFreeStripLayer> createState() => _HandsFreeStripLayerState();
}

class _HandsFreeStripLayerState extends State<HandsFreeStripLayer> {
  // One structure with or without the strip, and the child under a global
  // key: the navigator must keep its pages when the strip comes and goes.
  final _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    ActiveCallRegistry? registry;
    try {
      registry = Provider.of<ActiveCallRegistry>(context);
    } on ProviderNotFoundException {
      registry = null;
    }
    final microphone = registry == null
        ? null
        : registry.active
        ? registry.microphone
        : registry.microphoneMayBeOpen
        ? HandsFreeMicrophone.mayBeOpen
        : null;
    final shown = microphone != null;
    final colors = Theme.of(context).colorScheme;
    // The window's own inset: the status bar, a notch or the Mac title bar
    // (which `MacWindowChrome` reports as top padding). The strip sits under
    // it and the page below adds none.
    final inset = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        if (shown)
          Material(
            key: const Key('hands-free-strip'),
            color: colors.surface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, inset + 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: HandsFreeStrip(
                  microphone: microphone,
                  onEnd: registry!.active && !registry.screenOpen
                      ? () => unawaited(registry!.end())
                      : null,
                ),
              ),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: shown,
            child: KeyedSubtree(key: _childKey, child: widget.child),
          ),
        ),
      ],
    );
  }
}
