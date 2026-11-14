import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/files/widgets/safe_path_text.dart';
import 'package:hermes_app/src/files/widgets/server_path_text.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/workspaces/folder_labels.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/widgets/change_folder_confirmation.dart';

import '../support/fake_hermes_server.dart';

const _bidi = '/srv/\u202Eevil/gpj.exe';
const _isolate = '/srv/\u2066hidden/app';
const _crlf = '/srv/a\r\nb';
const _esc = '/srv/\u001B[2Jx';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildHermesLightTheme(),
  home: Scaffold(body: child),
);

void main() {
  group('safePathText', () {
    test('shows each control as a marked placeholder and drops nothing', () {
      expect(safePathText(_bidi), '/srv/⟨U+202E⟩evil/gpj.exe');
      expect(safePathText(_isolate), '/srv/⟨U+2066⟩hidden/app');
      expect(safePathText(_crlf), '/srv/a⟨U+000D⟩⟨U+000A⟩b');
      expect(safePathText(_esc), '/srv/⟨U+001B⟩[2Jx');
      expect(safePathText('a\u0085b\u007Fc؜d‏e'), contains('U+0085'));
      expect(safePathText('a\u007Fb'), 'a⟨U+007F⟩b');
    });

    test('leaves ordinary text, tabs and non-Latin names alone', () {
      for (final text in ['/home/me/code', 'a\tb', '/srv/données/日本語', '']) {
        expect(identical(safePathText(text), text), isTrue, reason: text);
      }
    });
  });

  testWidgets('a path view shows the placeholder, in text and in the '
      'semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const ServerPathText.text(_bidi)));

    expect(find.textContaining('⟨U+202E⟩', findRichText: true), findsOneWidget);
    expect(find.textContaining('\u202E', findRichText: true), findsNothing);
    final labels = tester.getSemantics(find.byType(ServerPathText)).label;
    expect(labels, contains('⟨U+202E⟩'));
    expect(labels, isNot(contains('\u202E')));
    handle.dispose();
  });

  testWidgets('a cut path and a wrapped path both show it', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [PathCutText(_esc), ServerPathText.text(_crlf, wrap: true)],
        ),
      ),
    );

    expect(find.textContaining('U+001B', findRichText: true), findsOneWidget);
    expect(find.textContaining('U+000D', findRichText: true), findsOneWidget);
  });

  testWidgets('the confirmation shows the folder safely', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showChangeFolderConfirmation(
              context,
              folderName: folderLabelFor(_bidi),
              path: _bidi,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.textContaining('⟨U+202E⟩'), findsWidgets);
    expect(find.textContaining('\u202E'), findsNothing);
  });

  test('a folder label shows it, and the move sends the original', () async {
    expect(folderLabelFor(_bidi), '/srv/⟨U+202E⟩evil/gpj.exe'.split('/').last);
    final sent = <Map<String, Object?>>[];
    final repository = HermesWorkspacesRepository(
      FakeHermesServer().client().raw,
      (method, params, {required timeout}) async {
        sent.add(params);
        return {'cwd': params['cwd']};
      },
    );

    await repository.moveWorkspace('s1', _bidi);

    expect(sent.single['cwd'], _bidi);
  });
}
