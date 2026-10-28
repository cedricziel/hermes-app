import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../telemetry/breadcrumbs.dart';
import '../../widgets/inspector_layout.dart' show kInspectorDockedMinWidth;
import '../widgets/bot_screen_viewer_view.dart';
import 'bot_screen_viewer.dart';
import 'bot_screen_viewer_controller.dart';

/// A viewer that is on screen. [close] is safe to call more than once and
/// after the viewer already left.
class BotScreenViewerHandle {
  BotScreenViewerHandle._(this.close);

  final VoidCallback close;
}

/// Shows [controller]'s viewer: a full-screen page below 760 points, a layer
/// over the whole window from there. [onClosed] runs once, as soon as the
/// viewer is gone, however it was closed (its Close button, Escape, the
/// system's Back, or [BotScreenViewerHandle.close]).
///
/// [source] (`card` or `preview`) and the surface go into the
/// `bot_screen.viewer.opened` and `.closed` breadcrumbs, which hold nothing
/// else.
BotScreenViewerHandle showBotScreenViewer(
  BuildContext context, {
  required BotScreenViewerController controller,
  required String profile,
  required String source,
  required VoidCallback onClosed,
  Breadcrumbs breadcrumbs = Breadcrumbs.none,
}) {
  final overlay = MediaQuery.sizeOf(context).width >= kInspectorDockedMinWidth;
  final surface = overlay ? 'overlay' : 'page';
  breadcrumbs('bot_screen.viewer.opened', {
    'surface': surface,
    'source': source,
  });
  var closed = false;
  void leave() {
    if (closed) return;
    closed = true;
    breadcrumbs('bot_screen.viewer.closed', {'surface': surface});
    onClosed();
  }

  late final VoidCallback close;
  if (overlay) {
    final entry = OverlayEntry(
      builder: (_) => BotScreenViewerOverlay(
        controller: controller,
        profile: profile,
        onClose: () => close(),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    close = () {
      if (closed) return;
      entry.remove();
      entry.dispose();
      leave();
    };
  } else {
    final navigator = Navigator.of(context, rootNavigator: true);
    late final MaterialPageRoute<void> route;
    route = MaterialPageRoute<void>(
      builder: (_) => BotScreenViewer(
        key: const Key('bot-screen-viewer-page'),
        controller: controller,
        profile: profile,
        presentation: BotScreenViewerPresentation.page,
        onClose: () {
          if (!route.isCurrent) return close();
          // The page slides away; the stream ends now.
          navigator.pop();
          leave();
        },
      ),
    );
    navigator.push(route).whenComplete(leave);
    close = () {
      if (closed) return;
      leave();
      void remove() {
        if (navigator.mounted && route.isActive) navigator.removeRoute(route);
      }

      // The owner can be unmounting, when the navigator must not change.
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) => remove());
      } else {
        remove();
      }
    };
  }
  return BotScreenViewerHandle._(close);
}
