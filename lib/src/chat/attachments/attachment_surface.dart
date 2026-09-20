import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../share/shared_item.dart';
import 'attachment_source.dart';

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

  Future<void> _openMenu() async {
    final origin = await showModalBottomSheet<AttachOrigin>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final origin in widget.source.origins)
              ListTile(
                leading: Icon(_icon(origin)),
                title: Text(_label(origin)),
                onTap: () => Navigator.of(context).pop(origin),
              ),
          ],
        ),
      ),
    );
    if (origin != null && mounted) await _pick(origin);
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

  void _dropped(List<SharedFile> files) {
    setState(() => _dragging = false);
    widget.onAdd(files);
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.builder(context, _openMenu);
    if (!widget.source.acceptsDropAndPaste) return chat;

    final onMac = defaultTargetPlatform == TargetPlatform.macOS;
    return Actions(
      actions: {
        _PasteAttachmentIntent: CallbackAction<_PasteAttachmentIntent>(
          onInvoke: (_) => _paste(),
        ),
      },
      child: Shortcuts(
        shortcuts: {
          SingleActivator(
            LogicalKeyboardKey.keyV,
            meta: onMac,
            control: !onMac,
          ): const _PasteAttachmentIntent(),
        },
        child: widget.source.dropTarget(
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
    );
  }
}

class _PasteAttachmentIntent extends Intent {
  const _PasteAttachmentIntent();
}

IconData _icon(AttachOrigin origin) => switch (origin) {
  AttachOrigin.files => Icons.insert_drive_file_outlined,
  AttachOrigin.photos => Icons.photo_library_outlined,
  AttachOrigin.camera => Icons.photo_camera_outlined,
};

String _label(AttachOrigin origin) => switch (origin) {
  AttachOrigin.files => 'Choose files',
  AttachOrigin.photos => 'Photo library',
  AttachOrigin.camera => 'Take a photo',
};

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
