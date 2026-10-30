import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_viewer_ids.dart';

void main() {
  test('the hash is the first 12 hex characters of the SHA-256', () {
    expect(BotScreenViewerIds.hashOf('viewer-1'), '63a9e8a8c2d8');
    expect(BotScreenViewerIds.hashOf('viewer-2'), '617ba8603143');
  });

  test('holds the hash of each id it was given, and no other', () {
    final ids = BotScreenViewerIds()
      ..add('viewer-1')
      ..add('viewer-2');

    expect(ids.holds('63a9e8a8c2d8'), isTrue);
    expect(ids.holds('617ba8603143'), isTrue);
    expect(ids.holds('66db64465437'), isFalse);
    expect(ids.holds(null), isFalse);
    expect(ids.hashes, {'63a9e8a8c2d8', '617ba8603143'});
  });

  test('the latest id is the one added last', () {
    final ids = BotScreenViewerIds();
    expect(ids.latest, isNull);

    ids
      ..add('viewer-1')
      ..add('viewer-2');

    expect(ids.latest, 'viewer-2');
  });

  test('adding an id again keeps it the latest one', () {
    final ids = BotScreenViewerIds()
      ..add('viewer-1')
      ..add('viewer-2')
      ..add('viewer-1');

    expect(ids.latest, 'viewer-1');
    expect(ids.hashes, hasLength(2));
  });

  test('printing it shows no id and no hash', () {
    final ids = BotScreenViewerIds()..add('viewer-1');

    expect('$ids', isNot(contains('viewer-1')));
    expect('$ids', isNot(contains('63a9e8a8c2d8')));
  });
}
