import 'package:flutter_test/flutter_test.dart';

/// A button VoiceOver can name on macOS, which reads a node's label only,
/// without iOS reading the name twice as label and tooltip.
Matcher namedButton(String name) =>
    isSemantics(label: name, tooltip: '', isButton: true, hasTapAction: true);

/// A disclosure header: a button that says whether its section is open.
Matcher disclosure(String name, {required bool open}) => isSemantics(
  label: name,
  isButton: true,
  hasTapAction: true,
  hasExpandedState: true,
  isExpanded: open,
);
