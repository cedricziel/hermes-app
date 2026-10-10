import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/quick_look_target.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_attachments.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// A solid colour; stretched, it stands in for a photo.
final Uint8List _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOoXn7zPwAGlwL73vKgVwAAAABJRU5ErkJggg==',
);

const _report = ChatAttachment(
  name: 'quarterly-report.pdf',
  kind: AttachmentKind.file,
  size: 482113,
);

const _task = KanbanAttachment(
  id: 1,
  filename: 'layout-review.pdf',
  size: 245760,
);

/// Static states: the selection frame around the plain-model widgets the
/// surfaces draw. The live use cases below do it with a real target.
Widget _states(List<(String, Widget)> rows) => frame(
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final (label, child) in rows) ...[
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        child,
        const SizedBox(height: 20),
      ],
    ],
  ),
  maxWidth: 520,
);

Widget _card({
  required bool selected,
  String? notice,
  bool error = false,
  bool loading = false,
}) => QuickLookSelectionFrame(
  selected: selected,
  borderRadius: BorderRadius.circular(kHermesRadius),
  child: AttachmentCardFrame(
    attachment: _report,
    notice: loading ? 'Downloading…' : notice,
    noticeIsError: error,
    trailing: loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          )
        : const Icon(Icons.download_outlined, size: 20),
  ),
);

Widget _thumbnail({required bool selected, bool loading = false}) =>
    QuickLookSelectionFrame(
      selected: selected,
      borderRadius: BorderRadius.circular(kHermesRadius),
      child: SizedBox(
        width: 240,
        height: 160,
        child: ImageThumbnailView(
          image: MemoryImage(_photo),
          name: 'photo.png',
          loading: loading,
        ),
      ),
    );

Widget _row({required bool selected, bool transferring = false}) =>
    QuickLookSelectionFrame(
      selected: selected,
      borderRadius: BorderRadius.circular(8),
      child: KanbanAttachmentRow(
        attachment: _task,
        transferring: transferring,
        onDownload: (_) {},
        onRemove: (_) {},
      ),
    );

/// A real [QuickLookTarget] in a Mac theme, reporting what it was asked to do.
class _Live extends StatefulWidget {
  const _Live({this.enabled = true});

  final bool enabled;

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  var _last = 'Nothing yet';

  void _say(String what) => setState(() => _last = what);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return Theme(
      data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Click to select. Double-click, Enter or Open: open. Space or '
            'Quick Look: preview. Right-click: menu.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          QuickLookTarget(
            borderRadius: BorderRadius.circular(kHermesRadius),
            onOpen: enabled ? () => _say('Open') : null,
            onToggle: enabled ? () => _say('Space: toggle Quick Look') : null,
            onShow: enabled ? () => _say('Menu: Quick Look') : null,
            onSave: enabled ? () => _say('Menu: Save…') : null,
            child: const AttachmentCardFrame(attachment: _report),
          ),
          const SizedBox(height: 16),
          Text('Last action: $_last'),
        ],
      ),
    );
  }
}

WidgetbookNode quickLookNode() => WidgetbookComponent(
  name: 'QuickLookTarget',
  useCases: [
    WidgetbookUseCase(
      name: 'File card states',
      builder: (_) => _states([
        ('Idle', _card(selected: false)),
        ('Selected', _card(selected: true)),
        ('Loading', _card(selected: false, loading: true)),
        ('Selected and loading', _card(selected: true, loading: true)),
        (
          'Failed',
          _card(
            selected: false,
            notice: mediaFailureMessage(MediaFailure.missing),
            error: true,
          ),
        ),
        (
          'Selected and failed',
          _card(
            selected: true,
            notice: mediaFailureMessage(MediaFailure.tooLarge),
            error: true,
          ),
        ),
      ]),
    ),
    WidgetbookUseCase(
      name: 'Image thumbnail states',
      builder: (_) => _states([
        ('Idle', _thumbnail(selected: false)),
        ('Selected', _thumbnail(selected: true)),
        ('Loading', _thumbnail(selected: false, loading: true)),
        ('Selected and loading', _thumbnail(selected: true, loading: true)),
      ]),
    ),
    WidgetbookUseCase(
      name: 'Kanban attachment row states',
      builder: (_) => _states([
        ('Idle', _row(selected: false)),
        ('Selected', _row(selected: true)),
        ('Transferring', _row(selected: false, transferring: true)),
        ('Selected and transferring', _row(selected: true, transferring: true)),
      ]),
    ),
    WidgetbookUseCase(
      name: 'Live, all actions',
      builder: (_) => frame(const _Live()),
    ),
    WidgetbookUseCase(
      name: 'Live, menu items disabled',
      builder: (_) => frame(const _Live(enabled: false)),
    ),
  ],
);
