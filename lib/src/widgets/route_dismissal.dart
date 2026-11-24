import 'package:material_ui/material_ui.dart';

/// Dismisses [context]'s active route with [result], preserving other routes.
/// Does nothing once the route has begun closing or its context is disposed.
void dismissRoute(BuildContext context, [Object? result]) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route == null || !route.isActive) return;
  final navigator = Navigator.of(context);
  if (route.isCurrent) {
    navigator.pop(result);
  } else {
    navigator.removeRoute(route, result);
  }
}

/// Binds Esc ([DismissIntent]) to [dismissRoute] around a dialog's [child], for
/// a dialog whose route does not close on Esc itself (an inert barrier).
///
/// The binding sits above a [FocusScope] of its own. A pointer click that
/// takes focus out of a field hands it to the nearest scope; with only the
/// route's scope above the binding, Esc would no longer reach it. Pass
/// [autofocus] when nothing inside takes focus on its own.
///
/// This is the one place under `lib/` that binds [DismissIntent] for a dialog
/// (`arch.dismiss-intent-binding`).
class DismissOnEscape extends StatelessWidget {
  const DismissOnEscape({
    super.key,
    this.autofocus = false,
    required this.child,
  });

  final bool autofocus;
  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      DismissIntent: CallbackAction<DismissIntent>(
        onInvoke: (_) => dismissRoute(context),
      ),
    },
    child: FocusScope(autofocus: autofocus, child: child),
  );
}
