import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_api/hermes_api.dart';

import '../telemetry/telemetry.dart';
import 'memory_usage.dart';

enum MemoryFailure implements Exception {
  unsupported('Memory inspection is unavailable on this server.'),
  profileUnavailable('This profile is no longer available.'),
  missing('This memory changed or disappeared. Refresh the list.'),
  unauthorized('Sign in again to read memories.'),
  malformed('The server returned an unreadable memory response.'),
  transport('Could not load memories. Try again.');

  const MemoryFailure(this.message);
  final String message;
}

class MemoryEntry {
  const MemoryEntry(
    this.id,
    this.label, {
    this.source,
    String? text,
    this.truncated = false,
  }) : text = text ?? label;
  final String id, label;
  final String? source;

  /// What Hermes stored; the node's [label] until the list read the text.
  final String text;

  /// [text] is only the part of the entry the graph carries.
  final bool truncated;
  MemoryTab get tab => MemoryTab.forSource(source);
}

/// The size each memory file may reach, from the profile's config; null when
/// the config does not say.
class MemoryLimits {
  const MemoryLimits({this.aboutYou, this.agentNotes});
  static const unknown = MemoryLimits();
  final int? aboutYou, agentNotes;
  int? of(MemoryTab tab) => switch (tab) {
    MemoryTab.aboutYou => aboutYou,
    MemoryTab.agentNotes => agentNotes,
  };
}

class MemoryDetail {
  const MemoryDetail(this.entry, this.content);
  final MemoryEntry entry;
  final String content;
}

class MemoryWriteFailure implements Exception {
  const MemoryWriteFailure(this.uncertain, this.message);
  final bool uncertain;
  final String message;
}

class MemoryRepository {
  MemoryRepository(this._api, {this.telemetry = const ConnectionTelemetry()});
  final DefaultApi _api;
  final ConnectionTelemetry telemetry;

  Future<List<MemoryEntry>> load(String profile) => _read('list', () async {
    final data = (await _api.getLearningGraphApiLearningGraphGet(
      profile: profile,
    )).data;
    if (data is! Map || data['nodes'] is! List) throw MemoryFailure.malformed;
    final entries = <MemoryEntry>[];
    final ids = <String>{};
    for (final row in data['nodes'] as List) {
      if (row is! Map || row['kind'] is! String) throw MemoryFailure.malformed;
      if (row['kind'] != 'memory') continue;
      final id = row['id'], label = row['label'], source = row['memorySource'];
      if (id is! String ||
          id.isEmpty ||
          label is! String ||
          label.isEmpty ||
          (source != null && source is! String) ||
          !ids.add(id)) {
        throw MemoryFailure.malformed;
      }
      entries.add(MemoryEntry(id, label, source: source as String?));
    }
    final cards = data['memory'] is List ? data['memory'] as List : const [];
    return List<MemoryEntry>.unmodifiable(
      await Future.wait([
        for (final (i, entry) in entries.indexed)
          _withText(entry, i < cards.length ? cards[i] : null, profile),
      ]),
    );
  });

  /// A card's `body` is the entry cut at this many characters.
  static const _cardBodyLimit = 1200;

  /// The graph's cards sit in the order of its memory nodes and carry the
  /// node's source and label as theirs, but no id: a card that does not
  /// agree with its node is not trusted.
  Future<MemoryEntry> _withText(
    MemoryEntry entry,
    Object? card,
    String profile,
  ) async {
    final body =
        card is Map &&
            card['source'] == (entry.source ?? card['source']) &&
            card['title'] == entry.label &&
            card['body'] is String
        ? card['body'] as String
        : null;
    MemoryEntry withText(String? text, {bool truncated = false}) => MemoryEntry(
      entry.id,
      entry.label,
      source: entry.source,
      text: text,
      truncated: truncated,
    );
    if (body != null && characterCount(body) < _cardBodyLimit) {
      return withText(body);
    }
    try {
      return withText((await detail(entry.id, profile)).content);
    } on MemoryFailure {
      return withText(body, truncated: true);
    }
  }

  Future<MemoryLimits> limits(String profile) => _read('limits', () async {
    final data = (await _api.getConfigApiConfigGet(profile: profile)).data;
    if (data is! Map) throw MemoryFailure.malformed;
    final memory = data['memory'];
    int? limit(String key) {
      final value = memory is Map ? memory[key] : null;
      return value is int && value > 0 ? value : null;
    }

    return MemoryLimits(
      aboutYou: limit('user_char_limit'),
      agentNotes: limit('memory_char_limit'),
    );
  });

  Future<MemoryDetail> detail(String id, String profile) =>
      _read('detail', () async {
        final data = (await _api.getLearningNodeApiLearningNodeGet(
          id: id,
          profile: profile,
        )).data;
        if (data is! Map ||
            data['ok'] != true ||
            data['id'] != id ||
            data['kind'] != 'memory' ||
            data['content'] is! String ||
            (data['label'] != null && data['label'] is! String)) {
          throw MemoryFailure.malformed;
        }
        return MemoryDetail(
          MemoryEntry(id, data['label'] as String? ?? 'Memory'),
          data['content'] as String,
        );
      });

  Future<void> mutate(String id, String profile, {String? content}) async {
    final operation = content == null ? 'delete' : 'save';
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        'memory.mutate',
        attributes: {...telemetry.serverAttributes, 'operation': operation},
      ),
    );
    var outcome = 'confirmed';
    try {
      final response = content == null
          ? await _api.deleteLearningNodeApiLearningNodeDelete(
              learningNodeRef: LearningNodeRef(id: id, profile: profile),
              profile: profile,
            )
          : await _api.updateLearningNodeApiLearningNodePut(
              learningNodeEdit: LearningNodeEdit(
                id: id,
                content: content,
                profile: profile,
              ),
              profile: profile,
            );
      final data = response.data;
      if (data is! Map ||
          data['ok'] is! bool ||
          (data['message'] != null && data['message'] is! String)) {
        throw const MemoryWriteFailure(
          true,
          'The server response could not confirm the change.',
        );
      }
      if (data['ok'] != true) {
        throw MemoryWriteFailure(
          false,
          data['message'] as String? ?? 'The server rejected the change.',
        );
      }
    } on Object catch (error) {
      final MemoryWriteFailure failure;
      if (error is MemoryWriteFailure) {
        failure = error;
      } else if (error is DioException &&
          error.response != null &&
          (error.response!.statusCode ?? 500) < 500) {
        final body = error.response!.data;
        failure = MemoryWriteFailure(
          false,
          body is Map && body['detail'] is String
              ? body['detail'] as String
              : 'The server rejected the change.',
        );
      } else {
        failure = const MemoryWriteFailure(
          true,
          'The change may have completed. Check the current memories before continuing.',
        );
      }
      outcome = failure.uncertain ? 'uncertain' : 'failed';
      throw failure;
    } finally {
      _quiet(() {
        span?.setAttribute('outcome', outcome);
        telemetry.events('memory.mutation_outcome', {
          'operation': operation,
          'category': outcome,
        });
      });
      _quiet(() => span?.end());
    }
  }

  Future<T> _read<T>(String operation, Future<T> Function() read) async {
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        'memory.fetch',
        attributes: {...telemetry.serverAttributes, 'operation': operation},
      ),
    );
    try {
      final result = await read();
      _quiet(() => span?.setAttribute('outcome', 'success'));
      return result;
    } on Object catch (error) {
      final failure = _failure(error, operation);
      _quiet(() {
        span?.setAttribute('outcome', failure.name);
        telemetry.events('memory.fetch_failed', {
          'operation': operation,
          'category': failure.name,
        });
      });
      throw failure;
    } finally {
      _quiet(() => span?.end());
    }
  }

  static MemoryFailure _failure(Object error, String operation) {
    if (error is MemoryFailure) return error;
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) return MemoryFailure.unauthorized;
      if (status == 404) {
        final body = error.response?.data;
        final detail = body is Map ? body['detail'] : null;
        if (detail is String &&
            detail.startsWith("Profile '") &&
            detail.endsWith('does not exist.')) {
          return MemoryFailure.profileUnavailable;
        }
        return operation == 'list'
            ? MemoryFailure.unsupported
            : MemoryFailure.missing;
      }
    }
    return MemoryFailure.transport;
  }

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
