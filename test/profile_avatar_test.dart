import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/profiles/profile_avatar_repository.dart';
import 'package:hermes_app/src/profiles/widgets/profile_avatar.dart';
import 'package:hermes_app/src/profiles/widgets/recipient_picker.dart';

const _writer = HermesProfile(name: 'writer', displayName: 'Writing partner');
const _research = HermesProfile(name: 'research', displayName: 'Researcher');
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAMElEQVR4nGNwylj7Hx9mwCc5+dhF3ApAkjgVwCSxKkCWxFCALomiAJskXAEuSRAGAMJVrJXCULtNAAAAAElFTkSuQmCC';
Map<String, Object?> _asset() => {
  'found': true,
  'mime': 'image/png',
  'data': 'data:image/png;base64,$_png',
};

ProfileAvatarRepository _repository(ProfileAssetRequest request) =>
    ProfileAvatarRepository(request, serverId: 'demo', accountId: 'account');

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  test(
    'reads the existing avatar contract and reuses canonical profile data',
    () async {
      final requests = <(String, Map<String, Object?>)>[];
      final repository = _repository((method, params) async {
        requests.add((method, params));
        return _asset();
      });
      addTearDown(repository.dispose);

      expect(await repository.load('writer'), base64Decode(_png));
      expect(await repository.load('writer'), base64Decode(_png));
      expect(requests, hasLength(1));
      expect(requests.single.$1, 'profiles.get_asset');
      expect(requests.single.$2, {'name': 'writer', 'asset': 'avatar'});
    },
  );

  test(
    'unsupported reads and external URLs fall back without another fetch',
    () async {
      final repository = _repository(
        (_, _) async => {
          'found': true,
          'data': 'https://images.example/avatar.png',
        },
      );
      final unsupported = _repository(
        (_, _) async => throw StateError('unsupported'),
      );
      addTearDown(repository.dispose);
      addTearDown(unsupported.dispose);

      expect(await repository.load('writer'), isNull);
      expect(await unsupported.load('writer'), isNull);
    },
  );

  test(
    'account disposal rejects pending results and releases cached bytes',
    () async {
      final pending = Completer<Map<String, Object?>>();
      final repository = _repository((_, _) => pending.future);
      final image = repository.load('writer');

      repository.dispose();
      pending.complete(_asset());

      expect(await image, isNull);
      expect(await repository.load('writer'), isNull);
    },
  );

  testWidgets(
    'monogram color follows canonical identity after a display rename',
    (tester) async {
      await _pump(tester, const ProfileAvatar(profile: _writer));
      final before = tester
          .widget<Container>(
            find.descendant(
              of: find.byType(InitialsAvatar),
              matching: find.byType(Container),
            ),
          )
          .decoration;

      await _pump(
        tester,
        const ProfileAvatar(
          profile: HermesProfile(
            name: 'writer',
            displayName: 'Editorial assistant',
          ),
        ),
      );
      final after = tester
          .widget<Container>(
            find.descendant(
              of: find.byType(InitialsAvatar),
              matching: find.byType(Container),
            ),
          )
          .decoration;

      expect(after, before);
      expect(find.text('EA'), findsOneWidget);
    },
  );

  testWidgets(
    'disposing the account clears a mounted avatar before replacement',
    (tester) async {
      final repository = _repository((_, _) async => _asset());
      await _pump(
        tester,
        ProfileAvatar(profile: _writer, repository: repository),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      repository.dispose();
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.text('WP'), findsOneWidget);
      await _pump(tester, const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('monogram keeps the full accessible recipient name', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await _pump(tester, const ProfileAvatar(profile: _writer));

    expect(find.text('WP'), findsOneWidget);
    expect(find.bySemanticsLabel('Writing partner'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('uses configured image and falls back when decoding fails', (
    tester,
  ) async {
    await _pump(
      tester,
      ProfileAvatar(profile: _writer, imageBytes: base64Decode(_png)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('WP'), findsNothing);

    await _pump(
      tester,
      ProfileAvatar(
        profile: _writer,
        imageBytes: Uint8List.fromList([1, 2, 3]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('WP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recipient change rejects a delayed avatar from the former profile',
    (tester) async {
      final pending = Completer<Map<String, Object?>>();
      final repository = _repository(
        (_, params) async =>
            params['name'] == 'writer' ? pending.future : {'found': false},
      );
      addTearDown(repository.dispose);
      await _pump(
        tester,
        ProfileAvatar(profile: _writer, repository: repository),
      );

      await _pump(
        tester,
        ProfileAvatar(profile: _research, repository: repository),
      );
      pending.complete(_asset());
      await tester.pumpAndSettle();

      expect(find.text('R'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets('account replacement clears the previously displayed avatar', (
    tester,
  ) async {
    final first = _repository((_, _) async => _asset());
    final second = ProfileAvatarRepository(
      (_, _) async => {'found': false},
      serverId: 'demo',
      accountId: 'other',
    );
    addTearDown(second.dispose);
    await _pump(tester, ProfileAvatar(profile: _writer, repository: first));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);

    first.dispose();
    await _pump(tester, ProfileAvatar(profile: _writer, repository: second));
    await tester.pumpAndSettle();

    expect(find.text('WP'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
    'recipient picker names profiles and returns the selected recipient',
    (tester) async {
      HermesProfile? selected;
      await _pump(
        tester,
        RecipientPicker(
          profiles: const [_writer, _research],
          onSelected: (profile) => selected = profile,
        ),
      );

      await tester.tap(find.text('Researcher'));

      expect(selected?.name, 'research');
      expect(find.text('Writing partner'), findsOneWidget);
      expect(find.byType(ProfileAvatar), findsNWidgets(2));
    },
  );

  testWidgets(
    'failed recipient listing offers retry without a fallback recipient',
    (tester) async {
      var retried = false;
      await _pump(
        tester,
        RecipientPicker(
          profiles: const [],
          failed: true,
          onRetry: () => retried = true,
          onSelected: (_) => fail('No recipient is available'),
        ),
      );

      await tester.tap(find.text('Retry'));

      expect(retried, isTrue);
      expect(find.byType(ProfileAvatar), findsNothing);
    },
  );
}
