import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show InMemoryChatController;
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/chat_composer.dart';
import 'package:hermes_app/src/chat/widgets/chat_thread_view.dart';
import 'package:hermes_app/src/models/widgets/composer_model_pill.dart';
import 'package:hermes_app/src/quick_panel/widgets/quick_panel_view.dart';
import 'package:hermes_app/src/quick_panel/widgets/shortcut_recorder_row.dart';
import 'package:hermes_app/src/voice/dictation_controller.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:hermes_app/src/voice/dictation_view.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:provider/provider.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_attachment_source.dart';
import 'fixtures.dart';
import 'frame.dart';

WidgetbookNode quickPanelNode() => WidgetbookFolder(
  name: 'Quick panel',
  children: [
    WidgetbookComponent(
      name: 'QuickPanelView',
      useCases: [
        _panel('Empty', const _Composer()),
        _panel(
          'Typing',
          const _Composer(text: 'What is on my calendar tomorrow?'),
        ),
        _panel(
          'Dictating',
          const _Composer(
            text: 'Please $dictationLiveTranscript',
            dictation: DictationPhase.recording,
          ),
        ),
        _panel(
          'Streaming',
          _Chat([
            _user('What changed in the release?'),
            _reply(
              'Three fixes landed: the retry cap, the upload timeout and',
              status: MessageStatus.streaming,
            ),
          ]),
          title: 'What changed in the release?',
          expanded: true,
        ),
        _panel(
          'Approval request',
          _Chat([
            _user('Clean up the build folder'),
            _reply('', requests: [pendingApproval]),
          ]),
          title: 'Clean up the build folder',
          expanded: true,
        ),
        _panel(
          'Failed reply',
          _Chat([
            _user('Summarise the incident'),
            _reply(
              '',
              status: MessageStatus.error,
              error: 'The model provider did not answer.',
            ),
          ]),
          title: 'Summarise the incident',
          expanded: true,
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ShortcutRecorderRow',
      useCases: [
        WidgetbookUseCase(
          name: 'No shortcut',
          builder: (_) => _row(chord: null),
        ),
        WidgetbookUseCase(
          name: 'Shortcut set',
          builder: (_) => _row(chord: '⌥Space'),
        ),
        WidgetbookUseCase(
          name: 'Narrow width',
          builder: (_) => _row(chord: '⌃⌥⌘K', maxWidth: 320),
        ),
      ],
    ),
  ],
);

/// The panel at its own size, on a Mac.
WidgetbookUseCase _panel(
  String name,
  Widget body, {
  String? title,
  bool expanded = false,
}) => WidgetbookUseCase(
  name: name,
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: QuickPanelView.width,
        height: expanded ? QuickPanelView.expandedHeight : null,
        child: QuickPanelView(
          title: title,
          onOpenInHermes: title == null ? null : () {},
          compact: !expanded,
          child: body,
        ),
      ),
    ),
  ),
);

final _at = DateTime.now();

ChatMessage _user(String text) =>
    ChatMessage(id: 'u1', role: ChatRole.user, content: text, createdAt: _at);

ChatMessage _reply(
  String text, {
  MessageStatus status = MessageStatus.sent,
  List<InputRequest> requests = const [],
  String? error,
}) => ChatMessage(
  id: 'a1',
  role: ChatRole.assistant,
  content: text,
  createdAt: _at,
  status: status,
  inputRequests: requests,
  error: error,
);

/// The panel before the first send: just the composer.
class _Composer extends StatefulWidget {
  const _Composer({this.text = '', this.dictation});

  final String text;
  final DictationPhase? dictation;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: ChatComposer(
      controller: _text,
      onSend: (_) {},
      onAttach: () {},
      onRemoveAttachment: (_) {},
      modelPill: ComposerModelPill(
        options: modelOptions,
        choice: null,
        onChanged: (_) {},
      ),
      dictation: switch (widget.dictation) {
        final phase? => DictationView(
          phase: phase,
          levels: dictationLevels,
          elapsed: const Duration(seconds: 4),
          canRetry: false,
          engine: DictationEngine.device,
          onSend: () {},
          onStart: () {},
          onStop: () {},
          onCancel: () {},
          onRetry: () {},
          onDismiss: () {},
        ),
        null => null,
      },
    ),
  );
}

/// The panel once the chat has messages: the chat's own thread view.
class _Chat extends StatefulWidget {
  const _Chat(this.messages);

  final List<ChatMessage> messages;

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  late final _thread = ChatThread(
    id: 's1',
    title: 'Quick question',
    updatedAt: _at,
    remote: true,
    messages: widget.messages,
  );
  late final _controller = InMemoryChatController(
    messages: [for (final m in widget.messages) ...chatMessageToFlyer(m)],
  );
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _latest = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _controller.dispose();
    _text.dispose();
    _focus.dispose();
    _latest.dispose();
    super.dispose();
  }

  Future<void> _answered(String requestId, Object? _) async {}

  @override
  Widget build(BuildContext context) => Provider<MediaStore?>.value(
    value: null,
    child: ChatThreadView(
      thread: _thread,
      chatController: _controller,
      composerController: _text,
      composerFocus: _focus,
      attachments: const [],
      attachmentSource: FakeAttachmentSource(),
      onAddAttachments: (_) {},
      onRemoveAttachment: (_) {},
      onSend: (_) {},
      onPickStarter: (_) {},
      latestReplyId: _latest,
      welcome: false,
      onRetry: () {},
      onAnswerApproval: _answered,
      onAnswerClarify: _answered,
      onStop: _thread.isReplying ? () async {} : null,
    ),
  );
}

/// The setting only exists on a Mac.
Widget _row({required String? chord, double maxWidth = 460}) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: frame(
      GroupedSection(
        children: [
          ShortcutRecorderRow(
            isSet: chord != null,
            recorder: RecorderStandIn(chord: chord),
          ),
        ],
      ),
      maxWidth: maxWidth,
    ),
  ),
);

/// Looks like the native recorder (a search field with the chord, or its
/// placeholder), which only exists in the Mac app.
class RecorderStandIn extends StatelessWidget {
  const RecorderStandIn({super.key, required this.chord});

  final String? chord;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          chord ?? 'Record Shortcut',
          style: TextStyle(
            fontSize: 12,
            color: chord == null ? scheme.onSurfaceVariant : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
