import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../share/shared_item.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../queued_prompt.dart';
import '../slash_command.dart';
import 'queued_prompts.dart';
import '../../widgets/named_icon_button.dart';

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

  bool get _canSend =>
      !widget.commandRunning &&
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  TextField(
                    key: chatComposerFieldKey,
                    controller: widget.controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: widget.replying
                          ? 'Queue a message…'
                          : 'Message Hermes…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.onAttach case final onAttach?)
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
