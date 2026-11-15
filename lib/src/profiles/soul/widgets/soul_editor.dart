import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../files/widgets/safe_path_text.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/grouped_list.dart';

/// From this many characters on the editor says that Hermes may shorten the
/// text when it builds a chat. It is a note, never a limit: the server has no
/// fixed ceiling, so nothing here blocks editing or saving at any length.
const int kSoulLongNoteLength = 20000;

/// The editor's controller. It draws a control or bidi character in the text
/// (the ones [safePathText] escapes) as a visible mark on a tinted
/// background, one UTF-16 unit for one unit so the caret and the selection
/// keep their offsets, and the text itself is never changed: what is saved is
/// what was loaded or typed. A tab and line breaks are drawn as they are.
class SoulTextController extends TextEditingController {
  SoulTextController({super.text});

  /// Whether the unit at [index] of [text] is drawn as a mark.
  static bool isHidden(int unit) =>
      unit != 0x0A && unit != 0x0D && isUnsafeDisplayRune(unit);

  /// The visible mark for a hidden unit: its control picture for a C0
  /// control, the picture of DEL, otherwise the replacement character.
  static String markFor(int unit) {
    if (unit < 0x20) return String.fromCharCode(0x2400 + unit);
    if (unit == 0x7F) return '␡';
    return '�';
  }

  /// Whether [text] holds anything [isHidden] says is drawn as a mark.
  static bool hasHidden(String text) => text.codeUnits.any(isHidden);

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
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    final tint = context.hermesColors.warning.withValues(alpha: 0.28);
    final marked = (style ?? const TextStyle()).copyWith(backgroundColor: tint);
    final underline = const TextStyle(decoration: TextDecoration.underline);
    final children = <TextSpan>[];
    final run = StringBuffer();
    var runHidden = false;
    var runComposing = false;
    void flush() {
      if (run.isEmpty) return;
      var s = runHidden ? marked : style;
      if (runComposing) s = (s ?? const TextStyle()).merge(underline);
      children.add(TextSpan(text: run.toString(), style: s));
      run.clear();
    }

    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      final hidden = isHidden(unit);
      final inComposing = i >= composing.start && i < composing.end;
      if (run.isNotEmpty &&
          (hidden != runHidden || inComposing != runComposing)) {
        flush();
      }
      runHidden = hidden;
      runComposing = inComposing;
      run.write(hidden ? markFor(unit) : text[i]);
    }
    flush();
    return TextSpan(style: style, children: children);
  }
}

/// A profile's personality text: one multiline field with a hint, a count of
/// characters under it, and the notes under that.
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
  /// [maxLines]. The parent must bound the height.
  final bool expands;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  /// How long typing must pause before the new count is announced.
  final Duration announceDelay;

  @override
  State<SoulEditor> createState() => _SoulEditorState();
}

class _SoulEditorState extends State<SoulEditor> {
  Timer? _pause;
  late int _announced = _count;

  int get _count => widget.controller.text.runes.length;

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
        // Null turns autofill off; an empty list would still opt in.
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
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.readOnly
            ? Colors.transparent
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(metrics.radius),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.rowPadding,
          vertical: 12,
        ),
        child: field,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expands) Expanded(child: box) else box,
        ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final text = widget.controller.text;
            final count = text.runes.length;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.rowPadding,
                8,
                metrics.rowPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    label: l10n.profilesSoulCount(_announced),
                    child: ExcludeSemantics(
                      child: Text(
                        l10n.profilesSoulCount(count),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: metrics.footerSize,
                          color: colors.subtleText,
                        ),
                      ),
                    ),
                  ),
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
          },
        ),
      ],
    );
  }
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
                size: metrics.footerSize + 3,
                color: muted,
              ),
            ),
          ),
          const SizedBox(width: 6),
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
