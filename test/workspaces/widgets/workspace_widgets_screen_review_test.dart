import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_browser_view.dart';
import 'package:hermes_app/src/workspaces/widgets/path_entry_view.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_details.dart';
import 'package:hermes_app/src/workspaces/widgets/working_directory_line.dart';
import 'package:hermes_app/src/workspaces/widgets/workspace_picker_view.dart';

import '../../files/widgets/files_widget_harness.dart';

void main() {
  testWidgets('the header line leaves the branch out when it does not fit', (
    tester,
  ) async {
    await pumpFiles(
      tester,
      const Center(
        child: SizedBox(
          width: 150,
          child: WorkingDirectoryLine(
            folderName: 'soil-survey',
            branch: 'feature/long-branch-name',
            belowBar: false,
          ),
        ),
      ),
    );

    expect(find.textContaining('soil-survey'), findsOneWidget);
    expect(find.textContaining('feature'), findsNothing);
    expect(find.textContaining('…'), findsNothing);
  });

  testWidgets('the header line keeps the branch when there is room', (
    tester,
  ) async {
    await pumpFiles(
      tester,
      const Center(
        child: SizedBox(
          width: 400,
          child: WorkingDirectoryLine(
            folderName: 'api',
            branch: 'main',
            belowBar: false,
          ),
        ),
      ),
    );

    expect(find.text('api · main'), findsOneWidget);
  });

  testWidgets('an unknown default has no second "Server default" tag, and a '
      'move has no default row at all', (tester) async {
    await pumpFiles(
      tester,
      const WorkspacePickerView(
        selectedId: 'default',
        serverDefault: WorkspacePickerRow(
          id: 'default',
          title: "Your server's default folder",
          path: '',
        ),
      ),
    );
    expect(find.text("Your server's default folder"), findsOneWidget);
    expect(find.textContaining('Server default'), findsNothing);

    await pumpFiles(tester, const WorkspacePickerView(selectedId: 'x'));
    expect(find.text("Your server's default folder"), findsNothing);
  });

  testWidgets('Use is available only for a level that was read', (
    tester,
  ) async {
    final enabled = <FolderBrowserLevel>[];
    for (final level in FolderBrowserLevel.values) {
      await pumpFiles(
        tester,
        FolderBrowserView(
          current: ServerPath.tryParse('/home/me')!,
          level: level,
          onUse: () {},
        ),
      );
      final view = tester.widget<FolderBrowserView>(
        find.byType(FolderBrowserView),
      );
      if (view.canUse) enabled.add(level);
    }

    expect(enabled, [FolderBrowserLevel.ready, FolderBrowserLevel.notAllowed]);
  });

  testWidgets('Change folder says why it waits for a restore', (tester) async {
    await pumpFiles(
      tester,
      const WorkingDirectoryDetails(
        folderName: 'api',
        path: '/home/me/api',
        restoring: true,
      ),
    );

    expect(
      find.text('Wait for the restore or compression to finish.'),
      findsOneWidget,
    );
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('working-directory-change')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a path with a placeholder is not selectable on a Mac, and '
      'Copy path copies the original', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final path = '/srv/${String.fromCharCode(0x202E)}evil/api';
    await pumpFiles(
      tester,
      WorkingDirectoryDetails(folderName: 'api', path: path),
      platform: TargetPlatform.macOS,
      size: const Size(700, 1200),
    );

    expect(find.byType(SelectionArea), findsNothing);
    await tester.tap(find.byKey(const Key('working-directory-copy-path')));
    await tester.pump();
    expect(copied, [path]);

    // An ordinary path keeps its selection and offers no extra button.
    await pumpFiles(
      tester,
      const WorkingDirectoryDetails(folderName: 'api', path: '/srv/api'),
      platform: TargetPlatform.macOS,
      size: const Size(700, 1200),
    );
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.byKey(const Key('working-directory-copy-path')), findsNothing);
  });

  testWidgets('Type a path shows a typed path with hidden characters '
      'escaped under the field', (tester) async {
    final typed = '/srv/${String.fromCharCode(0x202E)}evil';
    await pumpFiles(tester, PathEntryView(text: typed));

    expect(
      find.textContaining('The path has hidden characters: /srv/<U+202E>evil'),
      findsOneWidget,
    );

    await pumpFiles(tester, const PathEntryView(text: '/srv/ok'));
    expect(find.textContaining('hidden characters'), findsNothing);
  });
}
