import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/queued_prompt.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/chat_header.dart';
import 'package:hermes_app/src/chat/widgets/image_viewer.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/chat/widgets/queued_prompts.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/accessibility.dart';
import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';

Future<void> _pump(WidgetTester tester, Widget child, {MediaStore? store}) =>
    tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          Provider<MediaStore?>.value(value: store),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('a tool call header is a button that expands', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const ToolCallCard(
        call: ToolCall(name: 'lookup', summary: 'ls', result: 'a.txt'),
      ),
    );

    final header = find.text('lookup');
    expect(
      tester.getSemantics(header),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        isExpanded: false,
      ),
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(header),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a tool call without details is not a button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const ToolCallCard(
        call: ToolCall(name: 'lookup', summary: ''),
      ),
    );

    expect(
      tester.getSemantics(find.text('lookup')),
      isSemantics(isButton: false, hasExpandedState: false),
    );
    handle.dispose();
  });

  testWidgets('connection details has a name', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, ConnectionInfoButton(onPressed: () {}));

    expect(
      tester.getSemantics(find.byIcon(Icons.info_outline)),
      namedButton('Connection details'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('chat actions has a name', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      ThreadActionsButton(
        thread: ChatThread(id: 't1', title: 'Hi', updatedAt: DateTime(2026)),
      ),
    );

    expect(
      tester.getSemantics(find.byIcon(Icons.more_horiz)),
      namedButton('Chat actions'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a queued prompt can be removed by name', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      QueuedPrompts(
        prompts: const [QueuedPrompt('Next one', [])],
        onRemove: (_) {},
      ),
    );

    expect(
      tester.getSemantics(find.byIcon(Icons.close)),
      namedButton('Remove from queue'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('message actions are named', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, MessageActions(text: 'Reply', onRetry: () {}));

    expect(
      tester.getSemantics(find.byIcon(Icons.content_copy_outlined)),
      namedButton('Copy'),
    );
    expect(
      tester.getSemantics(find.byIcon(Icons.refresh)),
      namedButton('Try again'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the image viewer names close and save', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: ImageViewerPage(
          image: MemoryImage(kTinyPng),
          name: 'cat.png',
          onSave: () async => true,
        ),
      ),
    );

    expect(tester.getSemantics(find.byIcon(Icons.close)), namedButton('Close'));
    expect(
      tester.getSemantics(find.byIcon(Icons.download_outlined)),
      namedButton('Save'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a downloadable attachment names its save button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final server = FakeHermesServer();
    final cache = tempDir('a11y_media');
    await _pump(
      tester,
      const AttachmentCard(
        attachment: ChatAttachment(
          name: 'notes.pdf',
          kind: AttachmentKind.file,
          remotePath: '/tmp/notes.pdf',
        ),
      ),
      store: MediaStore(
        source: HermesMediaSource(() => server.client()),
        cacheDirectory: () async => cache,
      ),
    );

    expect(
      tester.getSemantics(find.byIcon(Icons.download_outlined)),
      namedButton('Save'),
    );
    handle.dispose();
  });

  testWidgets('the account menu is a button named Account', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: ThreadSidebar(
              threads: const [],
              selectedId: null,
              onSelect: (_) {},
              onNewThread: () {},
              onOpenSkills: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('Not connected')),
      isSemantics(
        label: 'Account\nNot connected',
        tooltip: '',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
