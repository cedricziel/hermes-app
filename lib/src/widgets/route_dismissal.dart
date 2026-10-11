import 'package:flutter/material.dart';

/// Dismisses [context]'s active route with [result], preserving other routes.
/// Does nothing once the route has begun closing or its context is disposed.
void dismissRoute<T extends Object?>(BuildContext context, [T? result]) {
  if (!context.mounted) return;
  final route = ModalRoute.of<T>(context);
  if (route == null || !route.isActive) return;
  final navigator = Navigator.of(context);
  if (route.isCurrent) {
    navigator.pop<T>(result);
  } else {
    navigator.removeRoute<T>(route, result);
  }
}
