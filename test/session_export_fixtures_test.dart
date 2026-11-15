import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The recorded answers of `GET /api/sessions/{id}/export` (see the README in
/// `test/fixtures/session_export/`), checked for the shapes the app will rely
/// on. The live check is in `real_backend_contract_test.dart`.
Map<String, dynamic> fixture(String name) => jsonDecode(
  File('test/fixtures/session_export/$name.json').readAsStringSync(),
) as Map<String, dynamic>;

void main() {
  for (final name in ['short', 'tools', 'undone', 'compacted']) {
    test('$name is a streamed JSON object with a string id and a list of '
        'messages', () {
      final answer = fixture(name);
      final headers = (answer['headers'] as Map).cast<String, String>();
      final body = answer['body'] as Map<String, dynamic>;

      expect(answer['status'], 200);
      expect(headers['content-type'], 'application/json');
      expect(headers['transfer-encoding'], 'chunked');
      expect(headers, isNot(contains('content-length')));
      expect(headers, isNot(contains('content-disposition')));
      expect(body['id'], isA<String>());
      final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
      expect(messages, isNotEmpty);
      for (final message in messages) {
        expect(message['role'], isA<String>());
        expect(message['session_id'], body['id']);
        expect(message['active'], anyOf(0, 1));
        expect(message['compacted'], anyOf(0, 1));
      }
    });
  }

  test('an undone turn and a compaction keep their inactive rows', () {
    final undone = (fixture('undone')['body'] as Map)['messages'] as List;
    expect(undone.where((m) => (m as Map)['active'] == 0), isNotEmpty);

    final compacted = (fixture('compacted')['body'] as Map)['messages'] as List;
    expect(compacted.where((m) => (m as Map)['compacted'] == 1), isNotEmpty);
  });

  test('the errors are JSON objects with a detail text', () {
    final expected = {
      'unknown_id': (404, 'Session not found'),
      'unknown_profile': (404, "Profile 'missing' does not exist."),
      'other_profile': (404, 'Session not found'),
      'wrong_method': (405, 'Method Not Allowed'),
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      final answer = fixture(key);
      expect(answer['status'], value.$1, reason: key);
      expect((answer['body'] as Map)['detail'], value.$2, reason: key);
    }
    expect(fixture('invalid_profile')['status'], 400);
    expect(
      ((fixture('invalid_profile')['body'] as Map)['detail'] as String),
      contains('is not a valid profile name'),
    );
    expect(
      ((fixture('wrong_route')['body'] as Map)['detail'] as String),
      startsWith('No such API endpoint'),
    );
  });
}
