import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/command_row.dart';

/// The command that brings an archived skill back, with its placeholders as
/// typed. It is what Copy puts on the clipboard: no skill and no profile name
/// is ever filled in.
const curatorRestoreCommand = 'hermes curator restore <name> -p <profile>';

/// What [CuratorRunConfirmation] words itself from. Only numbers and flags,
/// never text from the server; null means the status or config read did not
/// say.
class CuratorRunConfirmationModel {
  const CuratorRunConfirmationModel({
    this.staleAfterDays,
    this.archiveAfterDays,
    this.pruneBuiltins,
    this.consolidate,
  });

  final int? staleAfterDays;
  final int? archiveAfterDays;

  /// `curator.prune_builtins`: true, false, or unreadable (null).
  final bool? pruneBuiltins;

  /// `curator.consolidate`: true, false, or unreadable (null).
  final bool? consolidate;
}

/// The body of the question asked before a curator pass starts, for use
/// inside `showAdaptiveSheet`: what a pass may do, what it skips, that the
/// app cannot undo it, and the command that restores an archived skill.
///
/// The text above the buttons scrolls; Cancel and Run now stay in view. Cancel
/// is the default and takes the first focus, and the only emphasised button:
/// bold plain text on Apple platforms, a bold text button on Android, never
/// filled. Run now is outlined in the link colour on Apple platforms and a
/// text button on Android, never red. The back action, Escape and Return on
/// the default all call [onCancel]; only the Run now button calls [onRun].
/// Neither closes anything itself. A decided sheet closes from the next frame
/// on: back or Escape in the same frame as Run, before the rebuild, is
/// swallowed, and a second press closes it.
///
/// The buttons stack, Cancel on top, at a large text size everywhere and on an
/// Apple phone; [dialog] says the question sits in a dialog (iPad, a Mac,
/// a wide window), where they sit side by side.
class CuratorRunConfirmation extends StatefulWidget {
  const CuratorRunConfirmation({
    super.key,
    required this.model,
    required this.onCancel,
    required this.onRun,
    this.dialog = false,
  });

  final CuratorRunConfirmationModel model;
  final VoidCallback onCancel;
  final VoidCallback onRun;
  final bool dialog;

  /// From this scaled size of a 14 pt label (1.5x), the buttons stack.
  static bool stackedForText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) >= 21;

  @override
  State<CuratorRunConfirmation> createState() => _CuratorRunConfirmationState();
}

class _CuratorRunConfirmationState extends State<CuratorRunConfirmation> {
  final _scroll = ScrollController();

  /// Set before a callback runs, so a second tap, or Cancel and Run in the
  /// same frame, never reaches the caller: a pass is never started twice and
  /// a decision is never changed once made.
  var _decided = false;

  /// Marks the decision and lets the route be closed by back, the barrier or
  /// Escape from now on, whatever the caller does with its callback.
  void _decide() {
    _decided = true;
    setState(() {});
  }

  void _cancel() {
    if (_decided) return;
    _decide();
    widget.onCancel();
  }

  /// Escape decides like Cancel; once decided it only closes the route and
  /// calls nothing.
  void _escape() {
    if (_decided) {
      Navigator.maybePop(context);
    } else {
      _cancel();
    }
  }

  void _run() {
    if (_decided) return;
    _decide();
    widget.onRun();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chrome = platformChromeOf(context);
    final stacked =
        CuratorRunConfirmation.stackedForText(context) ||
        (chrome == PlatformChrome.ios && !widget.dialog);
    // The title stops growing at twice its size so a long German title does
    // not break inside a word; the body keeps scaling.
    final heading = Semantics(
      header: true,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 2,
        child: Text(
          context.l10n.skillsCuratorConfirmTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    final top = Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: 12),
          _Body(model: widget.model),
        ],
      ),
    );
    return PopScope(
      canPop: _decided,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (constraints.maxHeight.isFinite)
                  Flexible(
                    child: Scrollbar(
                      controller: _scroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        child: top,
                      ),
                    ),
                  )
                else
                  top,
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: _Buttons(
                    stacked: stacked,
                    onCancel: _cancel,
                    onRun: _run,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.model});

  final CuratorRunConfirmationModel model;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final stale = model.staleAfterDays;
    final archive = model.archiveAfterDays;
    final known = stale != null && archive != null;
    final builtins = model.pruneBuiltins;
    final consolidate = model.consolidate;
    final style = Theme.of(context).textTheme.bodyMedium;
    Widget line(String text) => Text(text, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line(l10n.skillsCuratorConfirmLead),
        const SizedBox(height: 12),
        _Item(
          icon: AppIcons.archive,
          lines: [
            known
                ? l10n.skillsCuratorConfirmStale(stale, archive)
                : l10n.skillsCuratorConfirmStaleUnknown,
            l10n.skillsCuratorConfirmStaleAgentMade,
          ],
        ),
        if (builtins != false) ...[
          const SizedBox(height: 10),
          _Item(
            icon: AppIcons.extension,
            lines: [
              builtins == true
                  ? l10n.skillsCuratorConfirmBuiltins
                  : l10n.skillsCuratorConfirmBuiltinsMaybe,
            ],
          ),
        ],
        if (consolidate != false) ...[
          const SizedBox(height: 10),
          _Item(
            icon: AppIcons.edit,
            lines: [
              consolidate == true
                  ? l10n.skillsCuratorConfirmConsolidate
                  : l10n.skillsCuratorConfirmConsolidateMaybe,
              l10n.skillsCuratorConfirmRollbackNote,
            ],
          ),
        ] else ...[
          const SizedBox(height: 12),
          line(l10n.skillsCuratorConfirmConsolidateOff),
        ],
        const SizedBox(height: 12),
        line(l10n.skillsCuratorConfirmSkipped),
        const SizedBox(height: 8),
        line(l10n.skillsCuratorConfirmArchived),
        const SizedBox(height: 16),
        line(l10n.skillsCuratorConfirmRestoreLead),
        const SizedBox(height: 8),
        const CommandRow(
          command: curatorRestoreCommand,
          copyBelowAtLargeText: true,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.skillsCuratorConfirmPlaceholders,
          style: style?.copyWith(color: context.hermesColors.subtleText),
        ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.lines});

  final AppIconSet icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    // The icon grows with the text so it keeps its place beside the first line.
    final size = MediaQuery.textScalerOf(context).scale(18);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: ExcludeSemantics(
            child: AppIcon(
              icon,
              size: size,
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(lines.join(' '), style: style)),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.stacked,
    required this.onCancel,
    required this.onRun,
  });

  final bool stacked;
  final VoidCallback onCancel;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chrome = platformChromeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final link = context.hermesColors.link;
    final minHeight = switch (chrome) {
      PlatformChrome.material => 48.0,
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
    };
    // A Mac button is about 28 pt tall, not the 36 pt that Material's
    // padding would give.
    final padding = chrome == PlatformChrome.macos
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 3)
        : null;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final cancel = TextButton(
      key: const ValueKey('curator-confirm-cancel'),
      autofocus: true,
      onPressed: onCancel,
      style: TextButton.styleFrom(
        foregroundColor: chrome.isApple ? scheme.onSurface : null,
        minimumSize: Size(chrome.isApple ? 0 : 64, minHeight),
        padding: padding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        shape: shape,
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: Text(l10n.skillsCuratorConfirmCancel, textAlign: TextAlign.center),
    );
    final run = chrome.isApple
        ? OutlinedButton(
            key: const ValueKey('curator-confirm-run'),
            onPressed: onRun,
            style: OutlinedButton.styleFrom(
              foregroundColor: link,
              side: BorderSide(color: link),
              minimumSize: Size(0, minHeight),
              padding: padding,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
              shape: shape,
            ),
            child: Text(
              l10n.skillsCuratorConfirmRun,
              textAlign: TextAlign.center,
            ),
          )
        : TextButton(
            key: const ValueKey('curator-confirm-run'),
            onPressed: onRun,
            style: TextButton.styleFrom(
              foregroundColor: link,
              minimumSize: Size(64, minHeight),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            ),
            child: Text(
              l10n.skillsCuratorConfirmRun,
              textAlign: TextAlign.center,
            ),
          );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [cancel, const SizedBox(height: 8), run],
      );
    }
    if (!chrome.isApple) {
      return Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [cancel, run],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: cancel),
          const SizedBox(width: 12),
          Expanded(child: run),
        ],
      ),
    );
  }
}
