import 'package:flutter/material.dart';

/// Lets the composer's text field paste images and files, which its own
/// Paste cannot: [AttachmentSurface] provides it around the chat.
class AttachmentPaste extends InheritedWidget {
  const AttachmentPaste({
    super.key,
    required this.hasFiles,
    required this.paste,
    required this.insert,
    required super.child,
  });

  /// Whether the clipboard may hold an image or files.
  final Future<bool> Function() hasFiles;

  /// Attaches the clipboard's image or files, or pastes its text when it
  /// holds neither.
  final Future<void> Function() paste;

  /// Attaches an image a keyboard inserted.
  final ValueChanged<KeyboardInsertedContent> insert;

  static AttachmentPaste? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AttachmentPaste>();

  /// For the text field's `contentInsertionConfiguration`.
  ContentInsertionConfiguration get contentInsertion =>
      ContentInsertionConfiguration(onContentInserted: insert);

  /// For the text field's `contextMenuBuilder`: the platform's menu, with a
  /// Paste that attaches when the clipboard holds an image or files. The
  /// field's own Paste only appears for text.
  Widget contextMenu(BuildContext context, EditableTextState state) =>
      _PasteAwareMenu(state: state, paste: this);

  @override
  bool updateShouldNotify(AttachmentPaste oldWidget) =>
      hasFiles != oldWidget.hasFiles ||
      paste != oldWidget.paste ||
      insert != oldWidget.insert;
}

class _PasteAwareMenu extends StatefulWidget {
  const _PasteAwareMenu({required this.state, required this.paste});

  final EditableTextState state;
  final AttachmentPaste paste;

  @override
  State<_PasteAwareMenu> createState() => _PasteAwareMenuState();
}

class _PasteAwareMenuState extends State<_PasteAwareMenu> {
  /// Unknown until the clipboard answered; the menu waits for it, since the
  /// system menu would show twice if it changed after appearing.
  bool? _hasFiles;

  @override
  void initState() {
    super.initState();
    if (widget.state.widget.readOnly) {
      _hasFiles = false;
      return;
    }
    widget.paste
        .hasFiles()
        .timeout(const Duration(milliseconds: 300), onTimeout: () => false)
        .catchError((Object _) => false)
        .then((hasFiles) {
          if (mounted) setState(() => _hasFiles = hasFiles);
        });
  }

  void _paste() {
    widget.state.hideToolbar();
    widget.paste.paste();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final hasFiles = _hasFiles;
    if (hasFiles == null) return const SizedBox.shrink();
    if (SystemContextMenu.isSupportedByField(state)) {
      final items = SystemContextMenu.getDefaultItems(state);
      return SystemContextMenu.editableText(
        editableTextState: state,
        items: hasFiles
            ? withFilePaste(
                items,
                IOSSystemContextMenuItemCustom(
                  title: WidgetsLocalizations.of(context).pasteButtonLabel,
                  onPressed: _paste,
                ),
                isPaste: (item) => item is IOSSystemContextMenuItemPaste,
                isCutOrCopy: (item) =>
                    item is IOSSystemContextMenuItemCut ||
                    item is IOSSystemContextMenuItemCopy,
              )
            : items,
      );
    }
    final items = state.contextMenuButtonItems;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: hasFiles
          ? withFilePaste(
              items,
              ContextMenuButtonItem(
                type: ContextMenuButtonType.paste,
                onPressed: _paste,
              ),
              isPaste: (item) => item.type == ContextMenuButtonType.paste,
              isCutOrCopy: (item) =>
                  item.type == ContextMenuButtonType.cut ||
                  item.type == ContextMenuButtonType.copy,
            )
          : items,
    );
  }
}

/// [items] with [paste] in place of the field's own Paste, or after Cut and
/// Copy when the clipboard held no text and the field offered none.
List<T> withFilePaste<T>(
  List<T> items,
  T paste, {
  required bool Function(T item) isPaste,
  required bool Function(T item) isCutOrCopy,
}) {
  final result = [...items];
  final existing = result.indexWhere(isPaste);
  if (existing >= 0) {
    result[existing] = paste;
  } else {
    result.insert(result.lastIndexWhere(isCutOrCopy) + 1, paste);
  }
  return result;
}
