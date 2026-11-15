import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../l10n/l10n.dart';
import '../../../files/widgets/safe_path_text.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/grouped_list.dart';
import 'soul_line_metrics.dart';

/// From this many characters on the editor says that Hermes may shorten the
/// text when it builds a chat. It is a note, never a limit: the server has no
/// fixed ceiling, so nothing here blocks editing or saving at any length.
const int kSoulLongNoteLength = 20000;

/// The editor's controller. It draws a control or bidi character in the text
/// (the ones [safePathText] escapes) as a visible mark on a tinted
/// background, one UTF-16 unit for one unit so the caret and the selection
/// keep their offsets, and the text itself is never changed: what is saved is
/// what was loaded or typed. A character above U+FFFF (a tag character, say)
/// is two units, so it is drawn as two marks. A tab and line breaks are drawn
/// as they are.
class SoulTextController extends TextEditingController {
  SoulTextController({super.text});

  /// Whether the UTF-16 [unit] is a character drawn as a mark. A unit that is
  /// half of a pair is judged by [hiddenUnits], not here.
  static bool isHidden(int unit) =>
      unit != 0x0A && unit != 0x0D && isUnsafeDisplayRune(unit);

  /// The visible mark for a hidden unit: its control picture for a C0
  /// control, the picture of DEL, otherwise the replacement character.
  static String markFor(int unit) {
    if (unit < 0x20) return String.fromCharCode(0x2400 + unit);
    if (unit == 0x7F) return '␡';
    return '�';
  }

  /// Whether [text] holds anything drawn as a mark.
  static bool hasHidden(String text) {
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (_isHigh(unit)) {
        final rune = _pairAt(text, i);
        if (rune == null || isUnsafeDisplayRune(rune)) return true;
        i++;
      } else if (_isLow(unit) || isHidden(unit)) {
        return true;
      }
    }
    return false;
  }

  /// For each UTF-16 unit of [text], whether it is drawn as a mark: a hidden
  /// character below U+10000, or either half of a hidden character above it.
  /// A lone surrogate (half of no pair) is drawn as a mark too: laid out as it
  /// is, it would make the text invalid UTF-16 and throw.
  @visibleForTesting
  static List<bool> hiddenUnits(String text) {
    final hidden = List<bool>.filled(text.length, false);
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (_isHigh(unit)) {
        final rune = _pairAt(text, i);
        if (rune == null) {
          hidden[i] = true;
        } else {
          if (isUnsafeDisplayRune(rune)) hidden[i] = hidden[i + 1] = true;
          i++;
        }
      } else {
        hidden[i] = _isLow(unit) || isHidden(unit);
      }
    }
    return hidden;
  }

  static bool _isHigh(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  static bool _isLow(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

  /// Whether [offset] sits between the two halves of a pair in [text].
  static bool _insidePair(String text, int offset) =>
      offset > 0 &&
      offset < text.length &&
      _isHigh(text.codeUnitAt(offset - 1)) &&
      _isLow(text.codeUnitAt(offset));

  /// [offset] moved out of the middle of a pair: to the pair's start when
  /// [forward] is false, to its end when true. Any other offset is returned
  /// as it is.
  static int _outOfPair(String text, int offset, {required bool forward}) =>
      _insidePair(text, offset) ? (forward ? offset + 1 : offset - 1) : offset;

  /// [selection] with no end inside a pair. A caret goes to the end of the
  /// pair it would have split. A range keeps covering what it covered: its
  /// lower end goes to the pair's start and its upper end to the pair's end,
  /// and the direction (which end is the base) is kept.
  static TextSelection _snapSelection(String text, TextSelection selection) {
    if (!selection.isValid) return selection;
    final base = selection.baseOffset;
    final extent = selection.extentOffset;
    if (!_insidePair(text, base) && !_insidePair(text, extent)) {
      return selection;
    }
    if (base == extent) {
      final caret = _outOfPair(text, base, forward: true);
      return selection.copyWith(baseOffset: caret, extentOffset: caret);
    }
    final baseIsLower = base < extent;
    return selection.copyWith(
      baseOffset: _outOfPair(text, base, forward: !baseIsLower),
      extentOffset: _outOfPair(text, extent, forward: baseIsLower),
    );
  }

  /// The same for the composing range, which is never a caret.
  static TextRange _snapComposing(String text, TextRange range) {
    if (!range.isValid || range.isCollapsed) return range;
    return TextRange(
      start: _outOfPair(text, range.start, forward: false),
      end: _outOfPair(text, range.end, forward: true),
    );
  }

  /// The caret and the composing range never stop between the two halves of a
  /// pair. A hidden character above U+FFFF is drawn as two marks, so a tap
  /// can land between them; a character typed or pasted there would split
  /// the pair into two lone surrogates. The text is never changed here.
  @override
  set value(TextEditingValue newValue) {
    final text = newValue.text;
    final selection = _snapSelection(text, newValue.selection);
    final composing = _snapComposing(text, newValue.composing);
    super.value =
        selection == newValue.selection && composing == newValue.composing
        ? newValue
        : newValue.copyWith(selection: selection, composing: composing);
  }

  /// The character whose high surrogate is at [i], or null when no low
  /// surrogate follows.
  static int? _pairAt(String text, int i) {
    if (i + 1 >= text.length) return null;
    final low = text.codeUnitAt(i + 1);
    if (low < 0xDC00 || low > 0xDFFF) return null;
    return 0x10000 + ((text.codeUnitAt(i) - 0xD800) << 10) + (low - 0xDC00);
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    if (!hasHidden(text)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final hiddenAt = hiddenUnits(text);
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final tint = context.hermesColors.warning.withValues(alpha: 0.28);
    final marked = (style ?? const TextStyle()).copyWith(backgroundColor: tint);
    const underline = TextStyle(decoration: TextDecoration.underline);
    final children = <TextSpan>[];
    var start = 0;
    var runHidden = false;
    var runComposing = false;
    // The run [start, end): plain text is one substring; a hidden run is one
    // mark per unit.
    void flush(int end) {
      if (end <= start) return;
      var s = runHidden ? marked : style;
      if (runComposing) s = (s ?? const TextStyle()).merge(underline);
      final shown = runHidden
          ? String.fromCharCodes([
              for (var i = start; i < end; i++)
                markFor(text.codeUnitAt(i)).codeUnitAt(0),
            ])
          : text.substring(start, end);
      children.add(TextSpan(text: shown, style: s));
    }

    for (var i = 0; i < text.length; i++) {
      final hidden = hiddenAt[i];
      final inComposing = i >= composing.start && i < composing.end;
      if (i > start && (hidden != runHidden || inComposing != runComposing)) {
        flush(i);
        start = i;
      }
      runHidden = hidden;
      runComposing = inComposing;
    }
    flush(text.length);
    return TextSpan(style: style, children: children);
  }
}

/// The number of characters (code points, as the server counts them) in the
/// text it is last asked about. Counting walks the whole string, which costs
/// milliseconds in a long file, so it runs again only when the text is not
/// the one it counted: a caret move notifies listeners without changing it.
class SoulCharacterCount {
  String? _text;
  int _count = 0;

  /// How many times a count actually ran.
  @visibleForTesting
  int computed = 0;

  int of(String text) {
    if (_text == null || !(identical(_text, text) || _text == text)) {
      _text = text;
      _count = text.runes.length;
      computed++;
    }
    return _count;
  }
}

/// A profile's personality text: one grouped card with a multiline field and
/// a hint, a divider, and a footer row with [footerAction] and the count of
/// characters; the notes sit under the card.
///
/// It takes plain values: a [controller] that holds the text, [fileExists] for
/// the line shown while the text is empty, and a callback. It owns no
/// repository and no save state; the screen decides when it is [readOnly]
/// (while a read, a save or a check runs, so the baseline cannot race the
/// text).
///
/// The field is filled while it can be edited and transparent while it is
/// read-only. Input is plain text: autocorrect, suggestions, smart quotes and
/// dashes, autofill, spell check, the keyboard's learning and a restoration
/// id are all off, since the text is instructions and Markdown and is never
/// stored by the keyboard. The count is announced politely once typing
/// pauses, not on every key. A long text only adds a note at
/// [kSoulLongNoteLength] characters; nothing is ever locked.
class SoulEditor extends StatefulWidget {
  const SoulEditor({
    super.key,
    required this.controller,
    required this.profile,
    this.fileExists = true,
    this.readOnly = false,
    this.minLines = 10,
    this.maxLines,
    this.expands = false,
    this.footerAction,
    this.focusNode,
    this.onChanged,
    this.announceDelay = const Duration(milliseconds: 800),
  });

  final SoulTextController controller;

  /// The profile the text belongs to; named in the field's accessibility label.
  final String profile;

  /// False when the profile has no SOUL.md yet: an empty editor then says so
  /// instead of naming the default personality.
  final bool fileExists;

  /// The text cannot be changed right now. The fill goes away and the text
  /// stays selectable.
  final bool readOnly;

  /// How tall the field is while it is empty, in lines of text.
  final int minLines;

  /// Where the field stops growing and scrolls; it grows with the text when
  /// null.
  final int? maxLines;

  /// Fills the height the parent gives it, ignoring [minLines] and
  /// [maxLines]. The parent must bound the height; its intrinsic height is
  /// the card's minimum ([fillMinLines] lines), not the text's.
  final bool expands;

  /// Lines of text the card keeps when it fills and the page is short: the
  /// page scrolls beneath it instead of shrinking it further.
  static const int fillMinLines = 12;

  /// A button at the card's footer, before the count: Revert on a phone. The
  /// card draws it with a divider above; the page owns what it does.
  final Widget? footerAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  /// How long typing must pause before the new count is announced.
  final Duration announceDelay;

  @override
  State<SoulEditor> createState() => _SoulEditorState();
}

/// What a test reads from the editor's state.
@visibleForTesting
abstract interface class SoulEditorCountProbe {
  int get debugCountComputed;
}

class _SoulEditorState extends State<SoulEditor>
    implements SoulEditorCountProbe {
  Timer? _pause;
  final _counter = SoulCharacterCount();
  late int _announced = _count;

  int get _count => _counter.of(widget.controller.text);

  @override
  int get debugCountComputed => _counter.computed;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_typed);
  }

  @override
  void didUpdateWidget(SoulEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_typed);
      widget.controller.addListener(_typed);
      _announced = _count;
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    widget.controller.removeListener(_typed);
    super.dispose();
  }

  void _typed() {
    _pause?.cancel();
    _pause = Timer(widget.announceDelay, () {
      if (mounted) setState(() => _announced = _count);
    });
  }

  /// The count, announced politely once typing pauses.
  Widget _countText(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Semantics(
        liveRegion: true,
        label: l10n.profilesSoulCount(_announced),
        child: ExcludeSemantics(
          child: Text(
            l10n.profilesSoulCount(_counter.of(widget.controller.text)),
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: metrics.footerSize,
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
      ),
    );
  }

  /// The hairline between the field and the footer: the text colour at 12 %
  /// over the card's fill. A scheme token cannot do it: `outlineVariant` is
  /// the fill itself in the light theme and `outline` is the fill in the dark
  /// one, so either draws no line in one of them.
  Color _dividerColor(ColorScheme scheme) => Color.alphaBlend(
    scheme.onSurface.withValues(alpha: 0.12),
    widget.readOnly ? scheme.surface : scheme.surfaceContainerHighest,
  );

  /// The card's bottom row: Revert (when the page gives one) at the leading
  /// edge, the count at the trailing edge. They wrap at large text.
  Widget _footer(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final action = widget.footerAction;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: 4,
      ),
      child: action == null
          ? Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _countText(context),
              ),
            )
          : _FooterRow(
              textDirection: Directionality.of(context),
              gap: 12,
              children: [action, _countText(context)],
            ),
    );
  }

  /// The info lines under the card: an empty file, a long text.
  Widget _notes(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final text = widget.controller.text;
        final count = _counter.of(text);
        if (text.isEmpty || count >= kSoulLongNoteLength) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              0,
              metrics.rowPadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (text.isEmpty)
                  SoulInfoLine(
                    text: widget.fileExists
                        ? l10n.profilesSoulEmptyFile
                        : l10n.profilesSoulNotSet,
                  ),
                if (count >= kSoulLongNoteLength)
                  SoulInfoLine(text: l10n.profilesSoulLongNote),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final expands = widget.expands;
    final field = Semantics(
      label: l10n.profilesSoulEditorLabel(widget.profile),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly,
        expands: expands,
        minLines: expands ? null : widget.minLines,
        maxLines: expands ? null : widget.maxLines,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        // TextField sends AutofillConfiguration.disabled only for null; its
        // default, an empty list, still registers the field for autofill.
        autofillHints: null,
        spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
        style: TextStyle(
          fontSize: metrics.titleSize,
          height: 1.35,
          color: scheme.onSurface,
        ),
        // The theme's focused border would otherwise draw a ring and pad the
        // text by its width once the field has focus; the fill carries the
        // field, so every border is off.
        decoration:
            InputDecoration.collapsed(
              hintText: l10n.profilesSoulHint,
              hintStyle: TextStyle(
                fontSize: metrics.titleSize,
                height: 1.35,
                color: colors.subtleText,
              ),
            ).copyWith(
              filled: false,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
        onChanged: widget.onChanged,
      ),
    );
    final fieldArea = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: 12,
      ),
      child: field,
    );
    // One grouped card: the field, a divider, then Revert and the count.
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.readOnly
            ? Colors.transparent
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(metrics.radius),
      ),
      child: Column(
        mainAxisSize: expands ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (expands) Expanded(child: fieldArea) else fieldArea,
          Divider(height: 1, color: _dividerColor(scheme)),
          _footer(context),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expands)
          Expanded(
            child: _IntrinsicHeight(
              height: _minCardHeight(context),
              child: card,
            ),
          )
        else
          card,
        _notes(context),
      ],
    );
  }

  /// What the card needs when it fills: [SoulEditor.fillMinLines] lines of
  /// text at the user's size, the field's padding and the footer row.
  double _minCardHeight(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final line =
        MediaQuery.textScalerOf(context).scale(metrics.titleSize) * 1.35;
    final footer = math.max(
      MediaQuery.textScalerOf(context).scale(metrics.footerSize) * 1.4 + 20,
      widget.footerAction == null ? 0 : 52,
    );
    return line * SoulEditor.fillMinLines + 24 + 1 + footer;
  }
}

/// The card's footer: the first child (Revert) at the leading edge and the
/// second (the count) at the trailing edge on one line, or, when the two do
/// not fit, the count on a line of its own, still at the trailing edge (a
/// `Wrap` would put a lone child at the start).
class _FooterRow extends MultiChildRenderObjectWidget {
  const _FooterRow({
    required this.textDirection,
    required this.gap,
    required super.children,
  });

  final TextDirection textDirection;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFooterRow(textDirection, gap);

  @override
  void updateRenderObject(BuildContext context, _RenderFooterRow renderObject) {
    renderObject
      ..textDirection = textDirection
      ..gap = gap;
  }
}

class _FooterParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFooterRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FooterParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FooterParentData> {
  _RenderFooterRow(this._textDirection, this._gap);

  TextDirection _textDirection;
  double _gap;

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FooterParentData) {
      child.parentData = _FooterParentData();
    }
  }

  RenderBox get _first => firstChild!;
  RenderBox get _second => childAfter(firstChild!)!;

  @override
  void performLayout() {
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    _first.layout(loose, parentUsesSize: true);
    _second.layout(loose, parentUsesSize: true);
    final a = _first.size;
    final b = _second.size;
    final oneLine = a.width + _gap + b.width <= constraints.maxWidth;
    final width = constraints.maxWidth;
    final height = oneLine ? math.max(a.height, b.height) : a.height + b.height;
    final firstTop = oneLine ? (height - a.height) / 2 : 0.0;
    final secondTop = oneLine ? (height - b.height) / 2 : a.height;
    final rtl = _textDirection == TextDirection.rtl;
    (_first.parentData! as _FooterParentData).offset = Offset(
      rtl ? width - a.width : 0,
      firstTop,
    );
    (_second.parentData! as _FooterParentData).offset = Offset(
      rtl ? 0 : width - b.width,
      secondTop,
    );
    size = constraints.constrain(Size(width, height));
  }

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    _first.getMinIntrinsicHeight(width),
    _second.getMinIntrinsicHeight(width),
  );

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    final a = _first.getDryLayout(loose);
    final b = _second.getDryLayout(loose);
    final oneLine = a.width + _gap + b.width <= constraints.maxWidth;
    return constraints.constrain(
      Size(
        constraints.maxWidth,
        oneLine ? math.max(a.height, b.height) : a.height + b.height,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Answers a parent's intrinsic-height question with [height] and lays its
/// child out as usual. A field that fills has no height of its own (its text
/// can be hundreds of thousands of characters long), but a page that scrolls
/// when the space is short must know how much the field needs.
class _IntrinsicHeight extends SingleChildRenderObjectWidget {
  const _IntrinsicHeight({required this.height, required Widget child})
    : super(child: child);

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderIntrinsicHeight(height);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderIntrinsicHeight renderObject,
  ) {
    renderObject.height = height;
  }
}

class _RenderIntrinsicHeight extends RenderProxyBox {
  _RenderIntrinsicHeight(this._height);

  double _height;

  set height(double value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;
}

/// A muted sentence with an info icon, under the count: the icon and the
/// words carry it, never a colour.
class SoulInfoLine extends StatelessWidget {
  const SoulInfoLine({super.key, required this.text, this.icon});

  final String text;
  final AppIconSet? icon;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AppIcon(
                icon ?? AppIcons.info,
                size: SoulLineMetrics.iconExtent(context),
                color: muted,
              ),
            ),
          ),
          const SizedBox(width: SoulLineMetrics.gap),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: metrics.footerSize, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
