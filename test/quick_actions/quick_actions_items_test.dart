import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/quick_actions/quick_actions_items.dart';
import 'package:hermes_app/src/surfaces/chat_hints.dart';
import 'package:hermes_app/src/surfaces/surface_snapshot.dart';

RecentChat chat(String id, String title, int minute, {String profile = 'a'}) =>
    RecentChat(
      profile: profile,
      id: id,
      title: title,
      updatedAt: DateTime.utc(2026, 1, 1, 12, minute),
    );

SurfaceSnapshot snapshot(List<RecentChat> chats) => SurfaceSnapshot(
  updatedAt: DateTime.utc(2026, 1, 1, 13),
  recentChats: chats,
);

void main() {
  test('a signed-out snapshot has no items', () {
    expect(
      quickActionItems(SurfaceSnapshot.signedOut(DateTime.utc(2026))),
      isEmpty,
    );
  });

  test('New Chat and Dictate come first, typed by their links', () {
    final items = quickActionItems(snapshot([]));

    expect(
      [for (final i in items) i.type],
      ['hermes://new', 'hermes://new?dictate=1'],
    );
    expect([for (final i in items) i.localizedTitle], ['New Chat', 'Dictate']);
  });

  test('the two newest chats follow, with their snapshot links', () {
    final chats = [
      chat('1', 'Old', 1),
      chat('2', 'Newest', 3),
      chat('3', 'Middle', 2),
    ];
    final items = quickActionItems(snapshot(chats));

    expect(items, hasLength(4));
    expect(
      [for (final i in items.skip(2)) i.localizedTitle],
      ['Newest', 'Middle'],
    );
    expect(items[2].type, chats[1].url);
    expect(items[3].type, chats[2].url);
  });

  test('untitled chats are skipped', () {
    final items = quickActionItems(
      snapshot([chat('1', '  ', 3), chat('2', 'Taxes', 2), chat('3', 'x', 1)]),
    );

    expect([for (final i in items.skip(2)) i.localizedTitle], ['Taxes', 'x']);
  });

  test('unnamed chats are skipped for the next titled ones', () {
    final items = quickActionItems(
      snapshot([
        chat('1', kUnnamedChatLabel, 4),
        chat('2', 'Taxes', 3),
        chat('3', kUnnamedChatLabel, 2),
        chat('4', 'Trip plan', 1),
      ]),
    );

    expect(
      [for (final i in items.skip(2)) i.localizedTitle],
      ['Taxes', 'Trip plan'],
    );
  });

  test('under App Lock only New Chat and Dictate are left', () {
    final items = quickActionItems(
      snapshot([chat('1', 'Secret', 2)]).redacted(),
    );

    expect(items, hasLength(2));
  });

  test('a long title is cut to 40 characters', () {
    final items = quickActionItems(snapshot([chat('1', 'a' * 70, 1)]));

    expect(items.last.localizedTitle.characters, hasLength(40));
    expect(items.last.localizedTitle, endsWith('…'));
  });

  group('subtitle', () {
    final mixed = snapshot([
      chat('1', 'One', 2),
      chat('2', 'Two', 1, profile: 'work'),
    ]);

    test('names the profile on iOS when several are listed', () {
      final items = quickActionItems(mixed, ios: true);

      expect(
        [for (final i in items.skip(2)) i.localizedSubtitle],
        ['a', 'work'],
      );
    });

    test('is left out with one profile', () {
      final items = quickActionItems(
        snapshot([chat('1', 'One', 2), chat('2', 'Two', 1)]),
        ios: true,
      );

      expect(items.every((i) => i.localizedSubtitle == null), isTrue);
    });

    test('is left out on Android', () {
      expect(
        quickActionItems(mixed).every((i) => i.localizedSubtitle == null),
        isTrue,
      );
    });
  });
}
