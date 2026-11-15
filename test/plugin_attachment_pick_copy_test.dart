import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/attachments/plugin_attachment_source.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'package:provider/provider.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_chat_transport.dart';

base class _Picked extends PlatformFile {
  _Picked(String path, this.name) : uri = Uri.file(path);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoSource implements MediaSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory pluginDir;
  late Directory cache;
  late MediaStore store;

  setUp(() {
    pluginDir = tempDir('file_picker_tmp');
    cache = tempDir('app_cache');
    store = MediaStore(source: _NoSource(), cacheDirectory: () async => cache);
  });

  PluginAttachmentSource sourceFor(
    List<File> picked, {
    TargetPlatform platform = TargetPlatform.iOS,
  }) => PluginAttachmentSource(
    platform: platform,
    staging: store,
    pickFiles: () async => [
      for (final file in picked) _Picked(file.path, file.uri.pathSegments.last),
    ],
  );

  List<File> partsIn(Directory dir) => dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.part'))
      .toList();

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test(
      'a file picked on $platform is copied out of the plugin directory',
      () async {
        final file = writeTemp(pluginDir, 'report.pdf', [1, 2, 3, 4]);

        final picked = await sourceFor([
          file,
        ], platform: platform).pick(AttachOrigin.files);

        expect(picked.single.name, 'report.pdf');
        expect(picked.single.path, isNot(startsWith(pluginDir.path)));
        expect(picked.single.path, startsWith(cache.path));
        expect(File(picked.single.path).readAsBytesSync(), [1, 2, 3, 4]);
        expect(partsIn(cache), isEmpty);
      },
    );
  }

  test('the display name is kept while the staged file name is safe', () async {
    final file = writeTemp(pluginDir, 'plain.pdf', [1]);
    final source = PluginAttachmentSource(
      platform: TargetPlatform.iOS,
      staging: store,
      pickFiles: () async => [_Picked(file.path, 'a:b.pdf')],
    );

    final picked = await source.pick(AttachOrigin.files);

    expect(picked.single.name, 'a:b.pdf');
    expect(picked.single.path.split('/').last, isNot(contains(':')));
  });

  test('clearing the plugin directory leaves the draft sendable', () async {
    final file = writeTemp(pluginDir, 'report.pdf', [9, 8, 7]);
    final picked = await sourceFor([file]).pick(AttachOrigin.files);

    // What FilePicker.clearTemporaryFiles does on iOS.
    pluginDir.deleteSync(recursive: true);
    pluginDir.createSync();

    final transport = FakeChatTransport();
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
    chat.newThread();
    expect(chat.submit('Read this', picked), isTrue);

    final sent = transport.sends.last.attachments.single;
    expect(sent.name, 'report.pdf');
    expect(await sent.read(), [9, 8, 7]);
  });

  test('a failed copy is an error and leaves no .part file', () async {
    final file = writeTemp(pluginDir, 'gone.pdf', [1]);
    final source = sourceFor([file]);
    file.deleteSync();

    await expectLater(source.pick(AttachOrigin.files), throwsException);

    expect(partsIn(cache), isEmpty);
  });

  test('a later file that fails removes the copies already made', () async {
    final keep = await store.stageCopy(
      'keep.txt',
      writeTemp(pluginDir, 'keep.txt', [5]),
    );
    final first = writeTemp(pluginDir, 'one.pdf', [1]);
    final source = PluginAttachmentSource(
      platform: TargetPlatform.iOS,
      staging: store,
      pickFiles: () async => [
        _Picked(first.path, 'one.pdf'),
        _Picked('${pluginDir.path}/nope.pdf', 'two.pdf'),
      ],
    );

    await expectLater(
      source.pick(AttachOrigin.files),
      throwsA(isA<MediaFetchException>()),
    );

    expect(keep.existsSync(), isTrue);
    expect(
      cache.listSync(recursive: true).whereType<File>().map((f) => f.path),
      [keep.path],
    );
    expect(
      cache
          .listSync(recursive: true)
          .whereType<Directory>()
          .where((d) => d.path != '${cache.path}/hermes_media')
          .map((d) => d.path),
      [keep.parent.path],
    );
  });

  test('a copy an earlier pick made survives a later failed pick', () async {
    final first = writeTemp(pluginDir, 'one.pdf', [1]);
    final earlier = await sourceFor([first]).pick(AttachOrigin.files);
    final source = PluginAttachmentSource(
      platform: TargetPlatform.iOS,
      staging: store,
      pickFiles: () async => [
        _Picked(first.path, 'one.pdf'),
        _Picked('${pluginDir.path}/nope.pdf', 'two.pdf'),
      ],
    );

    await expectLater(source.pick(AttachOrigin.files), throwsException);

    expect(File(earlier.single.path).existsSync(), isTrue);
  });

  testWidgets('.of hands the provided MediaStore to the source', (
    tester,
  ) async {
    late PluginAttachmentSource source;
    await tester.pumpWidget(
      Provider<MediaStore?>.value(
        value: store,
        child: Builder(
          builder: (context) {
            source = PluginAttachmentSource.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(source.staging, same(store));
  });

  testWidgets('.of without a provider has no store', (tester) async {
    late PluginAttachmentSource source;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          source = PluginAttachmentSource.of(context);
          return const SizedBox();
        },
      ),
    );

    expect(source.staging, isNull);
  });

  test('a desktop pick is not copied', () async {
    final file = writeTemp(pluginDir, 'report.pdf', [1]);

    final picked = await sourceFor([
      file,
    ], platform: TargetPlatform.macOS).pick(AttachOrigin.files);

    expect(picked.single.path, file.path);
    expect(cache.listSync(), isEmpty);
  });

  test('sign-out removes the copies like other staged files', () async {
    final file = writeTemp(pluginDir, 'report.pdf', [1]);
    final picked = await sourceFor([file]).pick(AttachOrigin.files);

    await store.clear();

    expect(File(picked.single.path).existsSync(), isFalse);
  });

  test('clearing the files downloads at App Lock keeps the copies', () async {
    final file = writeTemp(pluginDir, 'report.pdf', [1]);
    final picked = await sourceFor([file]).pick(AttachOrigin.files);

    await store.clearFileDownloads();

    expect(File(picked.single.path).existsSync(), isTrue);
  });

  test('every screen that builds the default source gives it the store', () {
    for (final path in [
      'lib/src/chat/chat_screen.dart',
      'lib/src/windows/conversation_window_screen.dart',
      'lib/src/quick_panel/quick_panel_screen.dart',
    ]) {
      final text = File(path).readAsStringSync();
      expect(
        text,
        contains('PluginAttachmentSource.of(context)'),
        reason: path,
      );
      expect(text, isNot(contains('PluginAttachmentSource()')), reason: path);
    }
  });
}
