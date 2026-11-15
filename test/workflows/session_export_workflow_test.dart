import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:provider/provider.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_media_actions.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

final _body = Uint8List.fromList(
  utf8.encode(
    jsonEncode({
      'id': 's1',
      'messages': [
        {'role': 'user', 'content': 'hi'},
      ],
    }),
  ),
);

/// Export chat as JSON: menu, confirmation, progress, saved, and one failure.
void main() {
  for (final size in [phoneSize, desktopSize]) {
    for (final brightness in Brightness.values) {
      final label =
          '${size == phoneSize ? 'phone' : 'desktop'}_'
          '${brightness.name}';
      testWidgets('exporting a chat as JSON, $label', (tester) async {
        final shots = ScreenshotRecorder('session_export_$label');
        Completer<FakeResponse>? held;
        var fail = false;
        final server = FakeHermesServer()
          ..on(
            'GET',
            '/api/profiles',
            profileListBody([
              profileRow(
                name: 'default',
                displayName: 'Personal',
                isDefault: true,
              ),
            ]),
          )
          ..on(
            'GET',
            '/api/profiles/active',
            activeProfileBody(active: 'default'),
          )
          ..on(
            'GET',
            '/api/sessions',
            sessionListBody([
              sessionRow(id: 's1', title: 'Plan the Lisbon trip'),
            ]),
          )
          ..on(
            'GET',
            '/api/sessions/s1/messages',
            messageListBody('s1', [
              messageRow(id: 1, role: 'user', content: 'Where should we stay?'),
              messageRow(id: 2, role: 'assistant', content: 'Alfama.'),
            ]),
          )
          ..onRequest('GET', '/api/sessions/s1/export', (_) async {
            if (fail) return (status: 500, body: {'detail': 'boom'});
            final gate = held;
            return gate == null
                ? (status: 200, body: _body)
                : await gate.future;
          });
        final cache = Directory.systemTemp.createTempSync('export-wf-');
        addTearDown(() => cache.deleteSync(recursive: true));
        final store = MediaStore(
          source: HermesMediaSource(() => server.client()),
          cacheDirectory: () async => cache,
          actions: FakeMediaActions(),
        );
        addTearDown(store.dispose);
        final profiles = ChatProfiles(
          HermesProfilesRepository(server.client().raw),
        );
        addTearDown(profiles.dispose);

        Future<void> frames() async {
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
        }

        await pumpScreen(
          tester,
          shots,
          ChatScreen(
            repository: HermesChatRepository(server.client().raw),
            profiles: HermesProfilesRepository(server.client().raw),
            chatProfiles: profiles,
            transport: FakeChatTransport(),
          ),
          size: size,
          brightness: brightness,
          providers: [
            Provider<HermesRepositories?>.value(
              value: HermesRepositories(server.client()),
            ),
            Provider<MediaStore?>.value(value: store),
          ],
        );
        await frames();
        await tester.tap(find.text('Plan the Lisbon trip').first);
        await frames();
        await shots.capture(tester, 'chat');

        await tester.tap(find.byKey(const Key('header-thread-actions')));
        await frames();
        await shots.capture(tester, 'menu');

        await tester.tap(find.text('Export chat as JSON…'));
        await frames();
        await shots.capture(tester, 'confirmation');

        held = Completer<FakeResponse>();
        await tester.tap(find.text('Export'));
        await frames();
        await shots.capture(tester, 'progress');

        held.complete((status: 200, body: _body));
        await frames();
        await shots.capture(tester, 'saved');

        fail = true;
        await tester.tap(find.byKey(const Key('header-thread-actions')));
        await frames();
        await tester.tap(find.text('Export chat as JSON…'));
        await frames();
        await tester.tap(find.text('Export'));
        await frames();
        await shots.capture(tester, 'failure');
      });
    }
  }
}
