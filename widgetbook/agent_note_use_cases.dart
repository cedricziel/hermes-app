import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_note_field.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _goal = 'Audit the dependency tree and list anything out of date';
const _typed = 'Skip the vendored packages and check only the direct ones.';

WidgetbookNode agentNoteNode() => WidgetbookComponent(
  name: 'Agent note field',
  useCases: [
    ...onEachPlatform('Empty', (_) => const _Note(text: '')),
    ...onEachPlatform('Typed', (_) => const _Note(text: _typed)),
    ...onEachPlatform(
      'Sending',
      (_) => const _Note(text: _typed, status: AgentNoteStatus.sending),
    ),
    ...onEachPlatform(
      'Counter from 3,500',
      (_) => _Note(text: 'x' * 3612, length: 3612),
    ),
    ...onEachPlatform(
      'Over 4,000',
      (_) => _Note(text: 'x' * 4100, length: 4100),
    ),
    ...onEachPlatform(
      'Queued with Your notes',
      (_) => const _Note(
        text: '',
        status: AgentNoteStatus.queued,
        sent: ['Use the lockfile as the source of truth.'],
      ),
    ),
    ...onEachPlatform(
      'Rejected',
      (_) => const _Note(text: _typed, status: AgentNoteStatus.rejected),
    ),
    ...onEachPlatform(
      'Lost answer',
      (_) => const _Note(text: _typed, status: AgentNoteStatus.lost),
    ),
    ...onEachPlatform(
      'Failed',
      (_) => const _Note(text: _typed, status: AgentNoteStatus.failed),
    ),
    ...onEachPlatform(
      'Missed',
      (_) => const _Note(text: _typed, status: AgentNoteStatus.missed),
    ),
    ...onEachPlatform(
      'Not sent with Copy',
      (_) => const _Note(text: _typed, frozen: true),
    ),
    ...onEachPlatform(
      'Offline',
      (_) => const _Note(text: _typed, offline: true),
    ),
    ...onEachPlatform(
      'Unsupported',
      (_) => const _Note(text: '', status: AgentNoteStatus.unsupported),
    ),
    ...onEachPlatform(
      'Largest text size',
      (_) => const _Note(text: _typed, scale: 3),
    ),
  ],
);

/// Holds the typed text so the field works in the catalog.
class _Note extends StatefulWidget {
  const _Note({
    required this.text,
    this.length,
    this.status = AgentNoteStatus.idle,
    this.frozen = false,
    this.offline = false,
    this.sent = const [],
    this.scale = 1,
  });

  final String text;
  final int? length;
  final AgentNoteStatus status;
  final bool frozen;
  final bool offline;
  final List<String> sent;
  final double scale;

  @override
  State<_Note> createState() => _NoteState();
}

class _NoteState extends State<_Note> {
  late var _text = widget.text;

  @override
  Widget build(BuildContext context) {
    final length = widget.length ?? _text.trim().length;
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(widget.scale)),
      child: frame(
        AgentNoteField(
          model: AgentNoteModel(
            goal: _goal,
            text: _text,
            length: length,
            status: widget.status,
            frozen: widget.frozen,
            offline: widget.offline,
            canSend: length > 0,
            sentNotes: widget.sent,
          ),
          onChanged: (value) => setState(() => _text = value),
          onSend: () {},
          onCopy: () {},
        ),
        maxWidth: 390,
      ),
    );
  }
}
