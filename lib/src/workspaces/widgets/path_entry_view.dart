import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/files_lazy_list.dart';
import '../../files/widgets/files_metrics.dart';
import '../../files/widgets/files_spinner.dart';
import '../../files/widgets/server_path_text.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/named_icon_button.dart';
import '../../widgets/settings_scaffold.dart';
import 'workspace_use_bar.dart';
import 'workspace_widget_support.dart';

/// What is known of the folder the typed text names.
enum PathEntryCheck {
  /// Nothing was checked: the text is still being typed.
  idle,

  /// The text does not start with `/` or `~`.
  relative,

  /// The server is being asked; at most 10 s.
  checking,

  /// The folder exists and can be read.
  found,

  /// The folder does not exist.
  missing,

  /// The folder exists but Hermes may not read it. "Use" stays enabled.
  notAllowed,

  /// The check had no answer for 10 s. Nothing is sent again by itself.
  tooSlow,

  /// The server does not let the app check folders: the choice is accepted
  /// and the chat says so if Hermes starts somewhere else.
  cannotCheck,
}

/// A folder the server suggests for the typed text.
class PathEntrySuggestion {
  const PathEntrySuggestion({required this.name, required this.path});

  /// The folder's name.
  final String name;

  /// The text the field takes when this is picked: the typed directory plus
  /// the name and a `/`.
  final String path;
}

/// Type a path: one outlined monospace field, "Folder on your server", the
/// folders the server suggests, and a filled "Use this folder".
///
/// Errors sit under the field in the error style and information in the helper
/// style. "Use this folder" is enabled for a folder that was found, one Hermes
/// may not read (with "Hermes may not be able to work here." above it) and a
/// server that cannot check; every other state disables it. It takes the
/// text, the answers and callbacks.
class PathEntryView extends StatefulWidget {
  const PathEntryView({
    super.key,
    required this.text,
    this.suggestions = const [],
    this.capped = false,
    this.check = PathEntryCheck.idle,
    this.autofocus = false,
    this.onChanged,
    this.onPickSuggestion,
    this.onUse,
    this.onCheckAgain,
  });

  final String text;
  final List<PathEntrySuggestion> suggestions;

  /// Hermes returned its 30 items, files and folders together, so a folder may
  /// be missing from [suggestions].
  final bool capped;
  final PathEntryCheck check;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<PathEntrySuggestion>? onPickSuggestion;
  final VoidCallback? onUse;
  final VoidCallback? onCheckAgain;

  /// Whether "Use this folder" is available for [check].
  static bool canUse(PathEntryCheck check) =>
      check == PathEntryCheck.found ||
      check == PathEntryCheck.notAllowed ||
      check == PathEntryCheck.cannotCheck;

  @override
  State<PathEntryView> createState() => _PathEntryViewState();
}

class _PathEntryViewState extends State<PathEntryView> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(PathEntryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (PathEntryView.canUse(widget.check)) widget.onUse?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final files = FilesMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final check = widget.check;
    final typed = widget.text.isNotEmpty;
    final noFolders =
        typed &&
        widget.suggestions.isEmpty &&
        !widget.capped &&
        check == PathEntryCheck.idle;
    final error = switch (check) {
      PathEntryCheck.relative => l10n.workspacesTypeRelative,
      PathEntryCheck.missing => l10n.workspacesTypeMissing,
      PathEntryCheck.tooSlow => l10n.workspacesTypeCouldntCheck,
      _ => null,
    };
    final info = switch (check) {
      PathEntryCheck.found => l10n.workspacesTypeFound,
      PathEntryCheck.notAllowed => l10n.workspacesTypeNotAllowed,
      PathEntryCheck.cannotCheck => l10n.workspacesTypeCannotCheck,
      PathEntryCheck.idle when noFolders => l10n.workspacesTypeNoFolders,
      _ => null,
    };
    final Widget? helper = check == PathEntryCheck.checking
        ? Semantics(
            liveRegion: true,
            child: Row(
              children: [
                const FilesSpinner(size: 14),
                const SizedBox(width: 8),
                Flexible(child: Text(l10n.workspacesTypeChecking)),
              ],
            ),
          )
        : info == null
        ? null
        : Semantics(liveRegion: true, child: Text(info));
    final field = Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        key: const Key('path-entry-field'),
        controller: _controller,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.url,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        textInputAction: TextInputAction.done,
        onChanged: widget.onChanged,
        onSubmitted: (_) => _submit(),
        style: TextStyle(
          fontFamily: kServerPathFont,
          fontSize: metrics.titleSize,
        ),
        decoration: InputDecoration(
          labelText: l10n.workspacesTypeLabel,
          hintText: l10n.workspacesTypeHint,
          hintStyle: TextStyle(fontFamily: kServerPathFont, color: muted),
          border: const OutlineInputBorder(),
          helper: helper,
          helperMaxLines: 6,
          error: error == null
              ? null
              : Semantics(liveRegion: true, child: Text(error)),
          errorMaxLines: 6,
          suffixIcon: typed
              ? NamedIconButton(
                  key: const Key('path-entry-clear'),
                  label: l10n.workspacesTypeClear,
                  icon: AppIcons.clearFilled,
                  iconSize: 20,
                  style: files.iconButtonStyle(),
                  onPressed: () => widget.onChanged?.call(''),
                )
              : null,
        ),
      ),
    );
    final leading = <Widget>[
      field,
      if (check == PathEntryCheck.tooSlow)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('path-entry-check-again'),
              onPressed: widget.onCheckAgain,
              style: files.buttonStyle(),
              child: Text(l10n.workspacesCheckAgain),
            ),
          ),
        ),
    ];
    return SettingsScaffold(
      title: l10n.workspacesTypeTitle,
      subtitle: l10n.workspacesPickerSubtitle,
      previousTitle: l10n.workspacesBrowseBack,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The field scrolls with the suggestions, so at a large text size
          // nothing is cut off and the button stays pinned.
          Expanded(child: _suggestions(context, leading)),
          WorkspaceUseBar(
            label: l10n.workspacesTypeUse,
            note: check == PathEntryCheck.notAllowed
                ? l10n.workspacesMayNotWork
                : null,
            onPressed: PathEntryView.canUse(check) ? widget.onUse : null,
          ),
        ],
      ),
    );
  }

  Widget _suggestions(BuildContext context, List<Widget> leading) {
    final l10n = context.l10n;
    final muted = context.hermesColors.subtleText;
    final suggestions = widget.suggestions;
    if (suggestions.isEmpty) {
      return GroupedListView(
        children: [
          ...leading,
          // Thirty items and none a folder: only the hint to keep typing.
          if (widget.capped)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.workspacesTypeKeepTyping,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted),
                ),
              ),
            ),
        ],
      );
    }
    final metrics = GroupedMetrics.of(context);
    final large = isLargeText(context);
    final pathStyle = TextStyle(fontSize: metrics.subtitleSize, color: muted);
    return FilesLazyList(
      leading: leading,
      dividerIndent: metrics.indentAfterLeading,
      itemCount: suggestions.length,
      footer: widget.capped ? l10n.workspacesTypeKeepTyping : null,
      itemBuilder: (context, i) {
        final item = suggestions[i];
        return GroupedRow(
          key: ValueKey(item.path),
          title: workspaceShortName(item.name, max: 48),
          titleMaxLines: large ? null : 1,
          leading: const AppIcon(AppIcons.folder),
          chevron: false,
          onTap: () => widget.onPickSuggestion?.call(item),
          details: [
            Semantics(
              label: item.path,
              excludeSemantics: true,
              child: large
                  ? Text(
                      item.path,
                      style: pathStyle.copyWith(fontFamily: kServerPathFont),
                    )
                  : PathCutText(item.path, style: pathStyle),
            ),
          ],
        );
      },
    );
  }
}
