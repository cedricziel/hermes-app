import 'package:flutter/widgets.dart';

/// The most characters of tool inputs and outputs that are coloured at once in
/// one chat, across every open card: 100,000 (about 100 KB). Each open text
/// takes its length from it and gives it back when its card closes, so many
/// open cards cannot each colour the 512 KB the Files limit allows one text.
const int kToolValueColourBudgetChars = 100000;

/// What the colouring of the open tool cards of one chat may cost, in
/// characters. A text that does not fit is shown plain and says so. It is
/// judged each time its section is built (the card opens, a row scrolls back
/// in, the text changes) and keeps its answer while it stays on screen.
///
/// Holds no text: owners are the sections' own state objects, and only the
/// length each was granted is kept.
class ToolValueBudget {
  ToolValueBudget({this.maxChars = kToolValueColourBudgetChars});

  final int maxChars;
  final _granted = <Object, int>{};
  var _used = 0;

  /// Characters granted to the open texts now.
  int get used => _used;

  /// Open texts holding a share.
  int get holders => _granted.length;

  /// Takes [chars] for [owner]; false when they do not fit. An owner that asks
  /// again is judged in place of its old share.
  bool admit(Object owner, int chars) {
    final before = _granted[owner] ?? 0;
    if (_used - before + chars > maxChars) return false;
    _used += chars - before;
    _granted[owner] = chars;
    return true;
  }

  /// Gives [owner]'s share back.
  void release(Object owner) {
    final share = _granted.remove(owner);
    if (share != null) _used -= share;
  }
}

/// Hands one [ToolValueBudget] to the tool cards below it. Without one the
/// cards colour within their own limits only.
class ToolValueBudgetScope extends InheritedWidget {
  const ToolValueBudgetScope({
    super.key,
    required this.budget,
    required super.child,
  });

  final ToolValueBudget budget;

  static ToolValueBudget? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ToolValueBudgetScope>()?.budget;

  @override
  bool updateShouldNotify(ToolValueBudgetScope old) => budget != old.budget;
}
