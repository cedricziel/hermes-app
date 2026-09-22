import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'approval_card.dart' show kAnswerFailedMessage;
import 'input_card_frame.dart';

/// The agent asks one question, or a batch, and waits. Answers stay on the card
/// until Send or Confirm, so a batch goes out together.
class ClarifyCard extends StatefulWidget {
  const ClarifyCard({super.key, required this.request, this.onAnswer});

  final ClarifyRequest request;

  /// Sends the values picked or typed per `qid`; an empty map skips the
  /// request. Throwing means it did not go through. Without one the controls
  /// are disabled.
  final Future<void> Function(Map<String, List<String>> answers)? onAnswer;

  @override
  State<ClarifyCard> createState() => _ClarifyCardState();
}

class _ClarifyCardState extends State<ClarifyCard> {
  final _picked = <String, List<String>>{};
  final _texts = <String, TextEditingController>{};
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _texts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _textFor(String qid) => _texts.putIfAbsent(
    qid,
    () => TextEditingController()..addListener(() => setState(() {})),
  );

  List<String> _answerFor(ClarifyQuestion q) {
    if (q.choices.isEmpty) {
      final text = _textFor(q.qid).text.trim();
      return text.isEmpty ? const [] : [text];
    }
    return _picked[q.qid] ?? const [];
  }

  bool get _ready =>
      widget.request.questions.every((q) => _answerFor(q).isNotEmpty);

  void _toggle(ClarifyQuestion q, String choice) {
    setState(() {
      final now = [...?_picked[q.qid]];
      if (!q.multiSelect) {
        _picked[q.qid] = [choice];
      } else {
        now.contains(choice) ? now.remove(choice) : now.add(choice);
        _picked[q.qid] = now;
      }
    });
  }

  Future<void> _submit(Map<String, List<String>> answers) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAnswer!(answers);
    } on Object catch (_) {
      if (mounted) setState(() => _error = kAnswerFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _input(ClarifyQuestion q) {
    if (q.choices.isEmpty) {
      return TextField(
        controller: _textFor(q.qid),
        enabled: !_busy,
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Type your answer',
        ),
      );
    }
    final picked = _picked[q.qid] ?? const [];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in q.choices)
          FilterChip(
            label: Text(choice),
            selected: picked.contains(choice),
            onSelected: _busy ? null : (_) => _toggle(q, choice),
          ),
      ],
    );
  }

  Widget _pending(ClarifyRequest request) {
    final enabled = !_busy && widget.onAnswer != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final q in request.questions) ...[
          Text(q.question),
          const SizedBox(height: 8),
          _input(q),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: enabled && _ready
                  ? () => _submit({
                      for (final q in request.questions) q.qid: _answerFor(q),
                    })
                  : null,
              child: Text(request.batch ? 'Confirm' : 'Send'),
            ),
            TextButton(
              onPressed: enabled ? () => _submit(const {}) : null,
              child: const Text('Skip'),
            ),
          ],
        ),
        if (_error != null) InputCardNote(_error!, error: true),
      ],
    );
  }

  Widget _answered(ClarifyRequest request) {
    if (request.answers.isEmpty) return const InputCardNote('Skipped');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final q in request.questions) ...[
          Text(q.question),
          InputCardNote(request.answers[q.qid]?.join(', ') ?? ''),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return InputCardFrame(
      icon: Icons.help_outline,
      title: 'Hermes has a question',
      child: switch (request.status) {
        InputRequestStatus.pending => _pending(request),
        InputRequestStatus.answered => _answered(request),
        InputRequestStatus.expired => const InputCardNote(
          'This request timed out',
        ),
      },
    );
  }
}
