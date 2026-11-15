import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../share/shared_item.dart';
import '../../widgets/adaptive_sheet.dart';
import 'attachment_paste.dart';
import 'attachment_source.dart';
import 'widgets/attach_menu.dart';

const _couldNotAttach = 'Could not attach that.';

/// Adds the ways of attaching that are not the share sheet around [builder]'s
/// chat: the attach menu, drops onto the chat and paste in the composer.
/// Whatever they produce goes to [onAdd]; the chat decides what to do with it.
class AttachmentSurface extends StatefulWidget {
  const AttachmentSurface({
    super.key,
    required this.source,
    required this.onAdd,
    required this.builder,
  });

  final AttachmentSource source;
  final ValueChanged<List<SharedFile>> onAdd;

  /// Builds the chat. [openMenu] belongs on its attach control.
  final Widget Function(BuildContext context, VoidCallback openMenu) builder;

  @override
  State<AttachmentSurface> createState() => _AttachmentSurfaceState();
}

class _AttachmentSurfaceState extends State<AttachmentSurface> {
  var _dragging = false;

  /// Set while the menu or a picker is open, so a second click cannot open
  /// another one (the Linux picker does not block the window).
  var _picking = false;

  Future<void> _openMenu() async {
    if (_picking) return;
    _picking = true;
    try {
      final origins = widget.source.origins;
      if (origins.length == 1) {
        await _pick(origins.single);
        return;
      }
      final origin = await showAdaptiveSheet<AttachOrigin>(
        context,
        maxWidth: 420,
        showDragHandle: true,
        maxSheetHeightFraction: 0.9,
        builder: (sheet) => AttachMenu(
          origins: origins,
          onPick: (origin) => Navigator.of(sheet).pop(origin),
        ),
      );
      if (origin != null && mounted) await _pick(origin);
    } finally {
      _picking = false;
    }
  }

  Future<void> _pick(AttachOrigin origin) async {
    try {
      final files = await widget.source.pick(origin);
      if (mounted) widget.onAdd(files);
    } on AttachmentUnavailable catch (e) {
      _say(e.message);
    } on Object {
      _say(_couldNotAttach);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Attaches an image or files from the clipboard. With neither, the paste is
  /// handed back to the text field that had the focus.
  Future<void> _paste() async {
    final focused = FocusManager.instance.primaryFocus?.context;
    final files = await widget.source.pasted();
    if (!mounted) return;
    if (files.isNotEmpty) {
      widget.onAdd(files);
    } else if (focused != null && focused.mounted) {
      Actions.maybeInvoke(
        focused,
        const PasteTextIntent(SelectionChangedCause.keyboard),
      );
    }
  }

  Future<void> _inserted(KeyboardInsertedContent content) async {
    try {
      final files = await widget.source.inserted(content);
      if (mounted && files.isNotEmpty) widget.onAdd(files);
    } on Object {
      _say(_couldNotAttach);
    }
  }

  void _dropped(List<SharedFile> files) {
    setState(() => _dragging = false);
    widget.onAdd(files);
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.builder(context, _openMenu);
    final source = widget.source;
    final apple = switch (defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    return AttachmentPaste(
      hasFiles: source.hasFilesToPaste,
      paste: _paste,
      insert: _inserted,
      child: Actions(
        actions: {
          _PasteAttachmentIntent: CallbackAction<_PasteAttachmentIntent>(
            onInvoke: (_) => _paste(),
          ),
        },
        child: Shortcuts(
          shortcuts: {
            SingleActivator(
              LogicalKeyboardKey.keyV,
              meta: apple,
              control: !apple,
            ): const _PasteAttachmentIntent(),
          },
          child: !source.acceptsDrops
              ? chat
              : source.dropTarget(
                  onHover: (over) => setState(() => _dragging = over),
                  onDrop: _dropped,
                  child: Stack(
                    children: [
                      chat,
                      if (_dragging) const Positioned.fill(child: _DropHint()),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PasteAttachmentIntent extends Intent {
  const _PasteAttachmentIntent();
}

/// Shown over the chat while files are dragged over it.
class _DropHint extends StatelessWidget {
  const _DropHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          border: Border.all(color: scheme.primary, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Drop files to attach',
          style: TextStyle(
            color: scheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
