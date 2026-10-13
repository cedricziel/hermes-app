import 'dart:convert';

class ProcessOutputUpdate {
  const ProcessOutputUpdate(this.processId, {this.chunk, this.closed = false});
  final String processId;
  final String? chunk;
  final bool closed;

  static ProcessOutputUpdate? decode(
    String type,
    Map<String, Object?> payload,
  ) {
    final id = payload['process_id'];
    if (id is! String || id.isEmpty) return null;
    if (type == 'terminal.close') return ProcessOutputUpdate(id, closed: true);
    final chunk = payload['chunk'];
    if (type != 'agent.terminal.output' || chunk is! String) return null;
    return ProcessOutputUpdate(id, chunk: chunk);
  }
}

class ProcessOutput {
  const ProcessOutput({
    required this.processId,
    this.text = '',
    this.closed = false,
    this.omitted = false,
  });
  final String processId, text;
  final bool closed, omitted;
}

enum ProcessOutputOutcome { applied, truncated, evicted, stale, ignored }

class ProcessOutputState {
  static const maxBytes = 64 * 1024;
  static const maxCards = 16;
  final _cards = <String, ProcessOutput>{};
  Object? _attachment;
  bool omittedCards = false;
  List<ProcessOutput> get cards => List.unmodifiable(_cards.values);
  bool hasScope(Object attachment) => _attachment == attachment;

  void adopt(Object attachment) {
    if (_attachment == attachment) return;
    clear();
    _attachment = attachment;
  }

  ProcessOutputOutcome apply(
    ProcessOutputUpdate update, {
    required Object attachment,
  }) {
    if (_attachment != attachment) return ProcessOutputOutcome.stale;
    if (update.processId.isEmpty || (!update.closed && update.chunk == null)) {
      return ProcessOutputOutcome.ignored;
    }
    var evicted = false;
    if (!_cards.containsKey(update.processId) && _cards.length == maxCards) {
      final closed = _cards.values.where((card) => card.closed);
      _cards.remove(
        closed.isEmpty ? _cards.keys.first : closed.first.processId,
      );
      omittedCards = true;
      evicted = true;
    }
    final old = _cards[update.processId];
    var text = '${old?.text ?? ''}${update.chunk ?? ''}';
    final bytes = utf8.encode(text);
    final truncated = bytes.length > maxBytes;
    if (truncated) {
      var start = bytes.length - maxBytes;
      while (start < bytes.length && (bytes[start] & 0xc0) == 0x80) {
        start++;
      }
      text = utf8.decode(bytes.sublist(start));
    }
    _cards[update.processId] = ProcessOutput(
      processId: update.processId,
      text: text,
      closed: update.closed || (old?.closed ?? false),
      omitted: truncated || (old?.omitted ?? false),
    );
    return evicted
        ? ProcessOutputOutcome.evicted
        : truncated
        ? ProcessOutputOutcome.truncated
        : ProcessOutputOutcome.applied;
  }

  void clear() {
    _cards.clear();
    omittedCards = false;
    _attachment = null;
  }
}
