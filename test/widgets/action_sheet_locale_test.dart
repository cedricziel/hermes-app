import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/swipeable_thread_row.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';

import '../support/test_localizations.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(platform: TargetPlatform.iOS),
  home: Scaffold(body: child),
);

void main() {
  final de = lookupAppLocalizations(const Locale('de'));

  testWidgets('the thread row sheet shows German labels', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        SwipeableThreadRow(
          title: 'Chat',
          pinned: false,
          onAction: (_) {},
          child: const ListTile(title: Text('Chat')),
        ),
      ),
    );
    await tester.longPress(find.text('Chat'));
    await tester.pumpAndSettle();
    for (final label in [
      de.chatWidgetsThreadMenuRename,
      de.chatWidgetsThreadMenuPin,
      de.chatWidgetsThreadMenuArchive,
      de.chatWidgetsThreadMenuDelete,
      de.widgetsCancel,
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('the row actions sheet shows a German Cancel', (tester) async {
    await tester.pumpWidget(
      _host(
        RowActions(
          title: 'Nightly',
          actions: [
            RowAction(label: 'X', icon: AppIcons.pause, onPressed: () {}),
          ],
          child: const ListTile(title: Text('Nightly')),
        ),
      ),
    );
    await tester.longPress(find.text('Nightly'));
    await tester.pumpAndSettle();
    expect(find.text(de.widgetsCancel), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });
}
