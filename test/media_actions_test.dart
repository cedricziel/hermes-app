import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/media/media_actions.dart';

import 'support/attachment_fixtures.dart';

void main() {
  test('saving a file over the cap is refused before it is read', () async {
    final dir = tempDir('media_actions');
    final file = writeTemp(dir, 'big.bin', List.filled(11, 1));
    const actions = PlatformMediaActions(maxSaveBytes: 10);

    await expectLater(
      actions.saveFile('big.bin', file),
      throwsA(isA<SaveTooLargeException>()),
    );
  });

  test('the refusal names neither the file nor its folder', () {
    expect(
      const SaveTooLargeException().toString(),
      isNot(anyOf(contains('/'), contains('big'))),
    );
  });

  test('the default cap is 32 MB', () {
    expect(const PlatformMediaActions().maxSaveBytes, 32 * 1024 * 1024);
  });
}
