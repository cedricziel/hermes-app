import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../telemetry/breadcrumbs.dart';
import '../widgets/bot_screen_viewer_view.dart';
import 'bot_screen_viewer.dart';
import 'bot_screen_viewer_controller.dart';

/// A viewer that is on screen. [close] is safe to call more than once and
/// after the viewer already left.
class BotScreenViewerHandle {
  BotScreenViewerHandle._(this.close);

  final VoidCallback close;
}

/// A window whose shortest side is under this is a phone, which gets the
/// viewer as a full-screen page whatever way it is turned.
const kViewerPhoneShortestSide = 600;

/// Shows [controller]'s viewer as a route on the root navigator, so a dialog
/// or page pushed later is drawn over it, the chat below is no longer the
/// current route (its menu commands and Back do not reach it), focus returns
/// where it was on close, and Back and Escape close it. On a phone (shortest
/// side under [kViewerPhoneShortestSide]) it is a full-screen page with the
/// platform's transition, elsewhere an opaque black layer over the whole
/// window. [onClosed] runs once, as soon as the viewer is gone, however it was
/// closed (its Close button, Escape, the system's Back, or
/// [BotScreenViewerHandle.close]).
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
  final page =
      MediaQuery.sizeOf(context).shortestSide < kViewerPhoneShortestSide;
  final surface = page ? 'page' : 'overlay';
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

  final navigator = Navigator.of(context, rootNavigator: true);
  late final PageRoute<void> route;
  late final VoidCallback close;
  Widget viewer(Key key, BotScreenViewerPresentation presentation) =>
      BotScreenViewer(
        key: key,
        controller: controller,
        profile: profile,
        presentation: presentation,
        breadcrumbs: breadcrumbs,
        onClose: () {
          if (!route.isCurrent) return close();
          // The route slides away; the stream ends now.
          navigator.pop();
          leave();
        },
      );
  route = page
      ? MaterialPageRoute<void>(
          builder: (_) => viewer(
            const Key('bot-screen-viewer-page'),
            BotScreenViewerPresentation.page,
          ),
        )
      : PageRouteBuilder<void>(
          opaque: true,
          barrierColor: Colors.black,
          transitionDuration: const Duration(milliseconds: 150),
          reverseTransitionDuration: const Duration(milliseconds: 100),
          pageBuilder: (_, _, _) => viewer(
            const Key('bot-screen-viewer-overlay'),
            BotScreenViewerPresentation.overlay,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
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
  return BotScreenViewerHandle._(close);
}
