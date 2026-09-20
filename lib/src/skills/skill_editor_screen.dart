import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'skill_detail_screen.dart' show skillMarkdownBody;

const newSkillTemplate = '''---
name:
description:
---

# Title

When to use this skill, and what to do.
''';

/// Edits a skill's `SKILL.md`, or writes a new one, with a rendered preview.
///
/// [onSave] returns null on success or a message to show; the screen then
/// pops with the skill's name. The text stays put when saving fails, and
/// leaving with unsaved changes asks first.
class SkillEditorScreen extends StatefulWidget {
  const SkillEditorScreen.edit({
    super.key,
    required String this.name,
    required this.initialText,
    required this.onSave,
  }) : creating = false;

  const SkillEditorScreen.create({super.key, required this.onSave})
    : creating = true,
      name = null,
      initialText = newSkillTemplate;

  final bool creating;
  final String? name;
  final String initialText;
  final Future<String?> Function(String name, String category, String text)
  onSave;

  @override
  State<SkillEditorScreen> createState() => _SkillEditorScreenState();
}

class _SkillEditorScreenState extends State<SkillEditorScreen> {
  late final _text = TextEditingController(text: widget.initialText);
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _undo = UndoHistoryController();
  bool _preview = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_text, _name]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _name.dispose();
    _category.dispose();
    _undo.dispose();
    super.dispose();
  }

  bool get _dirty => _text.text != widget.initialText;

  bool get _canSave =>
      !_saving && _dirty && (!widget.creating || _name.text.trim().isNotEmpty);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = widget.name ?? _name.text.trim();
    final error = await widget.onSave(name, _category.text.trim(), _text.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(name);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  void _insert(String snippet, {bool line = false}) {
    final value = _text.value;
    final sel = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final atLineStart = sel.start == 0 || value.text[sel.start - 1] == '\n';
    final prefix = line && !atLineStart ? '\n' : '';
    final text = value.text.replaceRange(sel.start, sel.end, '$prefix$snippet');
    final offset = sel.start + prefix.length + snippet.length;
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const CloseButton(),
          title: Text(widget.creating ? 'New skill' : 'Edit ${widget.name}'),
          actions: [
            TextButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
        body: Column(
          children: [
            if (widget.creating)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Edit')),
                  ButtonSegment(value: true, label: Text('Preview')),
                ],
                selected: {_preview},
                onSelectionChanged: (s) => setState(() => _preview = s.first),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(child: _preview ? _previewPane() : _editorPane()),
            if (!_preview) _toolbar(),
          ],
        ),
      ),
    );
  }

  Widget _editorPane() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: TextField(
      controller: _text,
      undoController: _undo,
      expands: true,
      maxLines: null,
      minLines: null,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      autocorrect: false,
      enableSuggestions: false,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.5,
      ),
      decoration: const InputDecoration(border: InputBorder.none),
    ),
  );

  Widget _previewPane() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: GptMarkdown(skillMarkdownBody(_text.text)),
  );

  Widget _toolbar() => SafeArea(
    top: false,
    child: Row(
      children: [
        for (final (label, snippet, line) in const [
          ('#', '# ', true),
          ('**', '****', false),
          ('•', '- ', true),
          ('</>', '```\n\n```', true),
        ])
          Expanded(
            child: TextButton(
              onPressed: () => _insert(snippet, line: line),
              child: Text(label),
            ),
          ),
        ValueListenableBuilder(
          valueListenable: _undo,
          builder: (context, value, _) => IconButton(
            onPressed: value.canUndo ? _undo.undo : null,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _undo,
          builder: (context, value, _) => IconButton(
            onPressed: value.canRedo ? _undo.redo : null,
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
          ),
        ),
      ],
    ),
  );
}
