import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/settings/about_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Hermes',
      packageName: 'com.cedricziel.hermesApp',
      version: '0.1.31',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('shows the version and a way to report a bug', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppAboutDialog(version: '0.1.31')),
    );

    expect(find.text('Version 0.1.31'), findsOneWidget);
    expect(find.text('Report a bug'), findsOneWidget);
  });

  testWidgets('reports a bug through the injected link opener', (tester) async {
    Uri? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: AppAboutDialog(
          version: '0.1.31',
          openLink: (uri) async {
            opened = uri;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Report a bug'));
    await tester.pump();

    expect(
      opened,
      Uri.parse('https://github.com/cedricziel/hermes-app/issues'),
    );
  });

  testWidgets('showAppAboutDialog opens it with the platform version', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showAppAboutDialog(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Version 0.1.31'), findsOneWidget);
  });
}
