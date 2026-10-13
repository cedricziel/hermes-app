import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_api/hermes_api.dart';

import '../telemetry/telemetry.dart';

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
  const MemoryEntry(this.id, this.label, {this.source});
  final String id, label;
  final String? source;
  String? get sourceLabel => switch (source) {
    'memory' => 'Memory',
    'profile' => 'User profile',
    _ => null,
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
    return List.unmodifiable(entries);
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
