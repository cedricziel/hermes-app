import 'package:flutter/widgets.dart';

/// Marks a settings page that sits in the detail pane beside a list instead of
/// being pushed on a route. Its [SettingsScaffold] then has no back button,
/// and the page leaves through [close], never by popping the route that holds
/// the whole screen.
class SettingsPane extends InheritedWidget {
  const SettingsPane({super.key, required this.close, required super.child});

  /// Empties the pane (the screen falls back to what it shows by default).
  final VoidCallback close;

  /// The pane [context] sits in, or null for a page on its own route. It
  /// does not subscribe: a page never moves between a pane and a route.
  static SettingsPane? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsPane>();

  @override
  bool updateShouldNotify(SettingsPane oldWidget) => false;
}

/// Whether [context] is a page in a detail pane.
bool inSettingsPane(BuildContext context) =>
    SettingsPane.maybeOf(context) != null;
