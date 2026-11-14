import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/workspaces/widgets/folder_browser_view.dart';
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
}
