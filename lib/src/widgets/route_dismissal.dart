import 'package:flutter/material.dart';

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
