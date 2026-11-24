import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/swipeable_thread_row.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.iOS),
  home: Scaffold(body: child),
);

bool _destructive(WidgetTester tester, String label) => tester
    .widget<CupertinoActionSheetAction>(
      find.widgetWithText(CupertinoActionSheetAction, label),
    )
    .isDestructiveAction;

void main() {
  testWidgets('the thread row sheet marks only Delete destructive', (
    tester,
  ) async {
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
    expect(_destructive(tester, 'Delete'), isTrue);
    for (final label in ['Rename', 'Pin', 'Archive', 'Cancel']) {
      expect(_destructive(tester, label), isFalse, reason: label);
    }
  });

  testWidgets('a row action sheet marks only destructive entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        RowActions(
          title: 'Nightly',
          actions: [
            RowAction(
              label: 'Turn off',
              icon: AppIcons.pause,
              onPressed: () {},
            ),
            RowAction(
              label: 'Remove',
              icon: AppIcons.delete,
              destructive: true,
              onPressed: () {},
            ),
          ],
          child: const ListTile(title: Text('Nightly')),
        ),
      ),
    );
    await tester.longPress(find.text('Nightly'));
    await tester.pumpAndSettle();
    expect(_destructive(tester, 'Remove'), isTrue);
    expect(_destructive(tester, 'Turn off'), isFalse);
  });
}
