import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `upgrader` 14 builds its dialog from `material_ui` and `cupertino_ui`, which
/// need the delegates and theme that `HermesApp` adds (`material_ui_bridge`).
/// The conversation-window and quick-panel apps do not have them, so no
/// upgrader widget may be built there.
void main() {
  test('only HermesApp and the update store use upgrader', () {
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('package:upgrader/'))
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toList();

    expect(
      users,
      everyElement(anyOf('lib/src/app.dart', startsWith('lib/src/update/'))),
      reason:
          'Add the material_ui bridge to the new MaterialApp (see '
          'lib/src/theme/material_ui_bridge.dart) before using upgrader there.',
    );
    expect(users, contains('lib/src/app.dart'));
  });
}
