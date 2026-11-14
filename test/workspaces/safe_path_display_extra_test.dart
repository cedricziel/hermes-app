import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/files/widgets/file_path_bar.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/files/widgets/files_questions.dart';
import 'package:hermes_app/src/files/widgets/middle_ellipsis.dart';
import 'package:hermes_app/src/files/widgets/safe_path_text.dart';
import 'package:hermes_app/src/files/widgets/server_path_text.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/ui/workspace_guard.dart';
import 'package:hermes_app/src/workspaces/ui/workspace_picker_sheet.dart';
import 'package:hermes_app/src/workspaces/widgets/workspace_picker_view.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';

final _rlo = String.fromCharCode(0x202E);
const _placeholder = r'⟨U\+[0-9A-F]{4,6}⟩';

/// No `⟨` without its whole placeholder after it.
void _expectWholePlaceholders(String text) {
  final opens = '⟨'.allMatches(text).length;
  final whole = RegExp(_placeholder).allMatches(text).length;
  expect(whole, opens, reason: text);
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildHermesLightTheme(),
  home: Scaffold(body: child),
);

void main() {
  test('more invisible and separating characters are escaped, and the '
      'joiners of Persian and Indic names are not', () {
    for (final code in [
      0x2028,
      0x2029,
      0x200B,
      0x2060,
      0x2064,
      0x206A,
      0x206F,
      0xFEFF,
    ]) {
      final hex = code.toRadixString(16).toUpperCase().padLeft(4, '0');
      expect(
        safePathText('a${String.fromCharCode(code)}b'),
        'a⟨U+$hex⟩b',
        reason: hex,
      );
    }
    for (final code in [0x200C, 0x200D, 0x2065]) {
      final text = 'a${String.fromCharCode(code)}b';
      expect(identical(safePathText(text), text), isTrue, reason: '$code');
    }
  });

  group('shortening never splits a placeholder', () {
    final name = '${'a' * 10}${String.fromCharCode(0x202E)}${'b' * 10}.txt';

    test('elideMiddle at every length', () {
      for (var max = 5; max < 30; max++) {
        _expectWholePlaceholders(
          elideMiddle(name, maxChars: max, keepExtension: true),
        );
        _expectWholePlaceholders(elideMiddle(name, maxChars: max));
      }
    });

    test('elidePathMiddle at every width', () {
      final path = '/srv/${'a' * 8}/${safePathText(name)}/api';
      for (var width = 8; width < 50; width++) {
        _expectWholePlaceholders(
          elidePathMiddle(path, (shown) => shown.characters.length <= width),
        );
      }
    });

    testWidgets('a wrapped name cut to its lines', (tester) async {
      for (final width in [60.0, 90.0, 120.0, 150.0, 200.0]) {
        await tester.pumpWidget(
          _app(
            Center(
              child: SizedBox(
                width: width,
                child: MiddleEllipsisText(name, maxLines: 1),
              ),
            ),
          ),
        );
        final shown = tester.widget<Text>(find.byType(Text).first).data!;
        _expectWholePlaceholders(shown);
      }
    });
  });

  testWidgets('the path bar tooltips and semantics are safe', (tester) async {
    final handle = tester.ensureSemantics();
    final path = ServerPath.tryParse('/srv/${_rlo}evil/inner')!;
    await tester.pumpWidget(_app(FilePathBar(current: path, onOpen: (_) {})));

    final tips = tester.widgetList<Tooltip>(find.byType(Tooltip));
    expect(tips, isNotEmpty);
    for (final tip in tips) {
      expect(tip.message, isNot(contains(_rlo)));
    }
    expect(tips.any((tip) => tip.message!.contains('U+202E')), isTrue);
    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label ?? '')
        .join('\n');
    expect(labels, isNot(contains(_rlo)));
    handle.dispose();
  });

  testWidgets('a Files row and the secret question show a name safely', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        FileRow(
          model: FileRowModel(name: 'a${_rlo}b.txt', isFolder: false),
          onTap: () {},
        ),
      ),
    );
    final label = tester.getSemantics(find.byType(FileRow)).label;
    expect(label, contains('U+202E'));
    expect(label, isNot(contains(_rlo)));
    handle.dispose();

    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => askOpenSecretFile(context, 'k${_rlo}ey.pem'),
            child: const Text('ask'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    expect(find.textContaining('U+202E'), findsOneWidget);
    expect(find.textContaining(_rlo), findsNothing);
  });

  testWidgets('a path bar and a path text keep ordinary names as they are', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ServerPathText.text('/home/me/données')),
    );

    expect(
      find.textContaining('/home/me/données', findRichText: true),
      findsOneWidget,
    );
  });

  group('a picker opened over a switch that already happened', () {
    late ChatController chat;
    late AttentionNotifier attention;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
    });

    tearDown(() {
      chat.dispose();
      attention.dispose();
    });

    testWidgets('closes at once and no pick lands', (tester) async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's1', title: 'One')]),
        )
        ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', []))
        ..on('GET', '/api/chat/workspaces', {
          'projects': [
            {
              'id': 'p',
              'name': 'Demo',
              'folders': [
                {'path': '/srv/demo', 'is_primary': true},
              ],
            },
          ],
          'repos': <Object?>[],
          'default_cwd': '/srv/a',
          'home': '/srv',
          'scan_enabled': false,
        });
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: FakeChatTransport(),
        workspaces: HermesWorkspacesRepository(
          server.client().raw,
          (method, params, {required timeout}) async => {},
        ),
        attention: attention,
        report: (_) {},
      );
      await tester.runAsync(() async {
        await chat.loadThreads();
        chat.newThread();
      });
      final guard = WorkspaceGuard(chat, trackSelection: true);
      addTearDown(guard.dispose);
      // The draft changes before the picker opens.
      chat.select('s1');
      expect(guard.closed.value, isTrue);
      var picked = 0;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showWorkspacePicker(
                context,
                chat: chat,
                guard: guard,
                onPick: (pick) async {
                  picked++;
                  return true;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(WorkspacePickerView), findsNothing);
      expect(picked, 0);
    });
  });
}
