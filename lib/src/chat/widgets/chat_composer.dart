import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../share/shared_item.dart';
import '../attachments/attachment_paste.dart';
import '../../bot_mode/bot_chat_context.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../queued_prompt.dart';
import '../slash_command.dart';
import 'queued_prompts.dart';
import '../../widgets/named_icon_button.dart';
import '../../voice/dictation_controller.dart';
import '../../voice/dictation_view.dart';
import '../../voice/widgets/dictation_notice.dart';
import '../../voice/widgets/voice_waveform.dart';
import '../../voice/dictation_settings.dart';

/// The composer's text field, for finding it among other fields.
const chatComposerFieldKey = Key('chat-composer-field');

/// The chat composer: a card with the text field on top and, below it,
/// attach, [modelPill], and send. The stop bar, the [queued] prompts and the
/// [attachments] are listed above the card.
///
/// [attachments] count as sendable content on their own, so a blank field
/// then sends an empty text through [onSend], which the caller pairs with its
/// pending attachments. The composer never clears [controller]: the caller
/// does once it accepts the send, so a refused send keeps the text. While
/// [replying] a send is queued, so the hint says so. Enter sends and
/// Shift+Enter breaks the line.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onSend,
    required this.onRemoveAttachment,
    this.onAttach,
    this.attachments = const [],
    this.replying = false,
    this.onStop,
    this.queued = const [],
    this.onRemoveQueued,
    this.onSendQueued,
    this.modelPill,
    this.slashCommands = const [],
    this.commandRunning = false,
    this.botContext,
    this.dictation,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSend;
  final VoidCallback? onAttach;
  final List<SharedFile> attachments;
  final ValueChanged<SharedFile> onRemoveAttachment;
  final bool replying;
  final Future<void> Function()? onStop;
  final List<QueuedPrompt> queued;
  final ValueChanged<QueuedPrompt>? onRemoveQueued;
  final VoidCallback? onSendQueued;
  final Widget? modelPill;
  final List<SlashCommand> slashCommands;
  final bool commandRunning;
  final BotChatContext? botContext;

  /// Dictation into the draft; without it there is no microphone button.
  final DictationView? dictation;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final _focusNode = widget.focusNode ?? FocusNode();
  late final KeyEventResult Function(FocusNode, KeyEvent) _keyHandler = _onKey;
  int _selectedSlash = 0;
  bool _dismissSlash = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.onKeyEvent = _keyHandler;
  }

  @override
  void didUpdateWidget(ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    _selectedSlash = 0;
    _dismissSlash = false;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else if (identical(_focusNode.onKeyEvent, _keyHandler)) {
      _focusNode.onKeyEvent = null;
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && _suggestions.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(
          () => _selectedSlash = (_selectedSlash + 1) % _suggestions.length,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(
          () => _selectedSlash =
              (_selectedSlash - 1 + _suggestions.length) % _suggestions.length,
        );
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _dismissSlash = true);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _chooseSlash(_suggestions[_selectedSlash % _suggestions.length]);
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      if (_suggestions.isNotEmpty &&
          widget.controller.text.trim() !=
              _suggestions[_selectedSlash % _suggestions.length].name) {
        _chooseSlash(_suggestions[_selectedSlash % _suggestions.length]);
        return KeyEventResult.handled;
      }
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<SlashCommand> get _suggestions {
    final text = widget.controller.text;
    if (_dismissSlash ||
        !text.startsWith('/') ||
        text.contains(RegExp(r'\s'))) {
      return const [];
    }
    return widget.slashCommands
        .where(
          (command) =>
              command.name.toLowerCase().startsWith(text.toLowerCase()),
        )
        .take(8)
        .toList();
  }

  void _chooseSlash(SlashCommand command) {
    widget.controller.value = TextEditingValue(
      text: '${command.name} ',
      selection: TextSelection.collapsed(offset: command.name.length + 1),
    );
    _focusNode.requestFocus();
  }

  List<BotMention> get _mentions =>
      widget.botContext?.suggestions(
        widget.controller.text,
        widget.controller.selection.baseOffset < 0
            ? widget.controller.text.length
            : widget.controller.selection.baseOffset,
      ) ??
      const [];

  void _chooseMention(BotMention mention) {
    final replacement = '@${mention.handle} ';
    widget.controller.value = TextEditingValue(
      text: widget.controller.text.replaceRange(
        mention.start,
        mention.end,
        replacement,
      ),
      selection: TextSelection.collapsed(
        offset: mention.start + replacement.length,
      ),
    );
    _focusNode.requestFocus();
  }

  bool get _canSend =>
      !widget.commandRunning &&
      widget.dictation?.active != true &&
      (widget.controller.text.trim().isNotEmpty ||
          widget.attachments.isNotEmpty);

  void _send() {
    if (_canSend) widget.onSend(widget.controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtle = context.hermesColors.subtleText;
    final onStop = widget.onStop;
    final onRemoveQueued = widget.onRemoveQueued;
    final modelPill = widget.modelPill;
    final dictation = widget.dictation;
    final dictating = dictation != null && dictation.active;
    final paste = AttachmentPaste.maybeOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mentions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: Material(
              color: scheme.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                    child: Text(
                      'Mention a teammate',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  for (final mention in _mentions)
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        title: Text('@${mention.handle}'),
                        subtitle: Text(
                          mention.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _chooseMention(mention),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (_mentions.isNotEmpty) const SizedBox(height: 8),
        if (_suggestions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final command = _suggestions[index];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    selected: index == _selectedSlash % _suggestions.length,
                    title: Text(command.name),
                    subtitle: Text(
                      command.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _chooseSlash(command),
                  ),
                );
              },
            ),
          ),
        if (onStop != null) _StopBar(onStop: onStop),
        if (widget.queued.isNotEmpty && onRemoveQueued != null)
          QueuedPrompts(
            prompts: widget.queued,
            onRemove: onRemoveQueued,
            onSendNow: widget.onSendQueued,
          ),
        if (widget.attachments.isNotEmpty)
          _AttachmentChips(
            attachments: widget.attachments,
            onRemove: widget.onRemoveAttachment,
          ),
        if (dictation != null && DictationNotice.shows(dictation.phase))
          DictationNotice(
            phase: dictation.phase,
            onDismiss: dictation.onDismiss,
            onRetry: dictation.canRetry ? dictation.onRetry : null,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(kHermesRadius + 6),
              border: Border.all(color: scheme.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (dictating)
                    VoiceWaveform(
                      levels: dictation.levels,
                      elapsed: dictation.elapsed,
                      liveTranscript: dictation.liveTranscript,
                      settling: dictation.phase == DictationPhase.settling,
                      onDevice: dictation.engine == DictationEngine.device,
                    )
                  else
                    TextField(
                      key: chatComposerFieldKey,
                      controller: widget.controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      contextMenuBuilder: paste?.contextMenu ?? _platformMenu,
                      contentInsertionConfiguration: paste?.contentInsertion,
                      decoration: InputDecoration(
                        hintText: widget.replying
                            ? 'Queue a message…'
                            : widget.botContext == null
                            ? 'Message Hermes…'
                            : 'Message ${widget.botContext!.title}…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                      ),
                    ),
                  Row(
                    children: [
                      if (dictating)
                        NamedIconButton(
                          label: 'Cancel voice input',
                          icon: AppIcons.close,
                          color: subtle,
                          onPressed: dictation.onCancel,
                        )
                      else if (widget.onAttach case final onAttach?)
                        NamedIconButton(
                          label: 'Add attachment',
                          icon: AppIcons.add,
                          color: subtle,
                          onPressed: onAttach,
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: modelPill,
                        ),
                      ),
                      if (dictation != null)
                        _DictationButton(dictation: dictation, color: subtle),
                      ListenableBuilder(
                        listenable: widget.controller,
                        builder: (context, _) => NamedIconButton(
                          label: 'Send',
                          icon: AppIcons.sendArrow,
                          filled: true,
                          // The app's icon button theme would paint the arrow
                          // in onSurface, invisible on a dark primary.
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            disabledBackgroundColor: scheme.onSurface
                                .withValues(alpha: 0.08),
                            disabledForegroundColor: subtle,
                          ),
                          onPressed: _canSend ? _send : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `TextField`'s own default, which a null builder would not give.
Widget _platformMenu(BuildContext context, EditableTextState state) =>
    SystemContextMenu.isSupportedByField(state)
    ? SystemContextMenu.editableText(editableTextState: state)
    : AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

/// Starts dictation, or stops the recording while one runs. Hidden while the
/// transcript settles.
class _DictationButton extends StatelessWidget {
  const _DictationButton({required this.dictation, required this.color});

  final DictationView dictation;
  final Color color;

  @override
  Widget build(BuildContext context) => switch (dictation.phase) {
    DictationPhase.recording => NamedIconButton(
      label: 'Stop voice input',
      icon: AppIcons.stopRecording,
      color: Theme.of(context).colorScheme.error,
      onPressed: dictation.onStop,
    ),
    DictationPhase.settling => const SizedBox.shrink(),
    _ => NamedIconButton(
      label: 'Dictate',
      icon: AppIcons.mic,
      color: color,
      onPressed: dictation.onStart,
    ),
  };
}

/// Shown while a reply is in flight, so it can be stopped.
class _StopBar extends StatefulWidget {
  const _StopBar({required this.onStop});

  final Future<void> Function() onStop;

  @override
  State<_StopBar> createState() => _StopBarState();
}

class _StopBarState extends State<_StopBar> {
  var _busy = false;

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onStop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Hermes is replying…',
              style: TextStyle(color: context.hermesColors.subtleText),
            ),
          ),
          TextButton.icon(
            onPressed: _busy ? null : _stop,
            icon: const AppIcon(AppIcons.stop),
            label: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}

class _AttachmentChips extends StatelessWidget {
  const _AttachmentChips({required this.attachments, required this.onRemove});

  final List<SharedFile> attachments;
  final ValueChanged<SharedFile> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final file in attachments)
              InputChip(
                avatar: AppIcon(
                  file.isImage ? AppIcons.image : AppIcons.file,
                  size: 16,
                ),
                label: Text(file.name),
                deleteButtonTooltipMessage: 'Remove ${file.name}',
                onDeleted: () => onRemove(file),
              ),
          ],
        ),
      ),
    );
  }
}
