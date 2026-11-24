import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

extension MaterialUiTooltipFinder on CommonFinders {
  /// [CommonFinders.byTooltip] for `material_ui`'s [Tooltip]. Flutter's
  /// finder reads the message off a tooltip that excludes itself from
  /// semantics (as `NamedIconButton`'s does) only when it is Flutter's own
  /// `Tooltip` class, so it misses every one of these.
  Finder tooltip(Pattern message, {bool skipOffstage = true}) {
    bool matches(String? text) =>
        message is RegExp ? message.hasMatch(text ?? '') : text == message;
    return byWidgetPredicate(
      (widget) {
        if (widget is Tooltip) {
          final text = widget.message ?? widget.richMessage!.toPlainText();
          if ((widget.excludeFromSemantics ?? false) || text.isEmpty) {
            return matches(text);
          }
        }
        return widget is RawTooltip && matches(widget.semanticsTooltip);
      },
      description: 'tooltip "$message"',
      skipOffstage: skipOffstage,
    );
  }
}
