import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/deep_links/deep_link_target.dart';
import 'package:hermes_app/src/deep_links/deep_link_uri.dart';

const _fixture = 'ios/HermesSurfaceKit/Tests/Fixtures/deep_links.json';
const _update = 'UPDATE_DEEP_LINK_FIXTURE';

DeepLinkTarget _target(Map<String, Object?> json) => switch (json['kind']) {
  'chat' => OpenChat(
    profile: json['profile'] as String?,
    threadId: json['id']! as String,
    prompt: json['prompt'] as String?,
  ),
  'new' => NewChat(
    profile: json['profile'] as String?,
    dictate: json['dictate'] == true,
    prompt: json['prompt'] as String?,
  ),
  'requests' => const OpenRequests(),
  'kanban' => const OpenKanban(),
  'schedules' => OpenSchedules(
    profile: json['profile'] as String?,
    jobId: json['job'] as String?,
  ),
  _ => throw ArgumentError('unknown kind ${json['kind']}'),
};

/// The inputs `DeepLink` in Swift has to build the same URLs for. The first
/// four are the links a widget falls back to.
const _cases = <(String, Map<String, Object?>)>[
  ('new chat', {'kind': 'new'}),
  ('requests', {'kind': 'requests'}),
  ('kanban', {'kind': 'kanban'}),
  ('schedules', {'kind': 'schedules'}),
  ('new chat with dictation', {'kind': 'new', 'dictate': true}),
  ('chat', {'kind': 'chat', 'profile': 'default', 'id': 'abc'}),
  ('chat without a profile', {'kind': 'chat', 'id': 'abc'}),
  ('chat with spaces', {'kind': 'chat', 'profile': 'my bot', 'id': 'w 1'}),
  ('chat with an ampersand', {'kind': 'chat', 'profile': 'a&b', 'id': 'c&d'}),
  ('chat with slashes', {'kind': 'chat', 'profile': 'a/b', 'id': 'x/y/z'}),
  (
    'chat with percent signs',
    {'kind': 'chat', 'profile': '50%', 'id': 'a%20b'},
  ),
  ('chat with a plus', {'kind': 'chat', 'profile': 'default', 'id': 'c++'}),
  (
    'chat with non-ASCII ids',
    {'kind': 'chat', 'profile': 'Büro', 'id': 'ü-日本-🚀'},
  ),
  (
    'chat with a prompt',
    {'kind': 'chat', 'id': 'abc', 'prompt': 'Yes, book it'},
  ),
  (
    'new chat with every parameter',
    {
      'kind': 'new',
      'profile': 'work',
      'dictate': true,
      'prompt': 'Plan a trip & 🚀',
    },
  ),
  ('new chat with C++', {'kind': 'new', 'prompt': 'C++'}),
  ('new chat with reserved characters', {'kind': 'new', 'prompt': 'a=b?c#d'}),
  (
    'schedules with a job',
    {'kind': 'schedules', 'profile': 'work', 'job': 'j 1'},
  ),
];

void main() {
  test('deep_links.json holds what deepLinkUri builds', () {
    final expected = [
      for (final (name, target) in _cases)
        {
          'name': name,
          'target': target,
          'url': deepLinkUri(_target(target)).toString(),
        },
    ];

    if (Platform.environment[_update] == '1') {
      File(_fixture).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(expected)}\n',
      );
    }

    expect(
      jsonDecode(File(_fixture).readAsStringSync()),
      expected,
      reason: 'Run the test with $_update=1 to rewrite $_fixture.',
    );
  });
}
