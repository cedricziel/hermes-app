import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/subagents/widgets/agent_widget_parts.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';

/// What happened to the last note, or why there is no field.
enum AgentNoteStatus {
  idle,
  sending,
  queued,
  rejected,
  lost,
  failed,
  missed,
  unsupported,
  notControllable,
}

/// What [AgentNoteField] draws.
class AgentNoteModel {
  const AgentNoteModel({
    required this.goal,
    this.text = '',
    this.length = 0,
    this.limit = 4000,
    this.status = AgentNoteStatus.idle,
    this.frozen = false,
    this.canSend = false,
    this.sentNotes = const [],
    this.offline = false,
  });

  AgentNoteModel copyWith({bool? offline, bool? canSend}) => AgentNoteModel(
    goal: goal,
    text: text,
    length: length,
    limit: limit,
    status: status,
    frozen: frozen,
    canSend: canSend ?? this.canSend,
    sentNotes: sentNotes,
    offline: offline ?? this.offline,
  );

  final String goal;
  final String text;

  /// The trimmed character count, counted by the caller.
  final int length;
  final int limit;
  final AgentNoteStatus status;

  /// The text can no longer be sent: it shows read-only as "Not sent".
  final bool frozen;
  final bool canSend;

  /// Notes sent while the detail stayed open, oldest first.
  final List<String> sentNotes;
  final bool offline;
}

/// The counter appears from this many characters.
const kNoteCounterFrom = 3500;

/// The section where the user writes a note to one agent.
///
/// A plain bordered field with its own Send button, not the chat composer. It
/// may hold secrets, so autofill, autocorrect, suggestions and keyboard
/// learning are off. [controller] holds the typed text when the caller owns
/// it; without one the field keeps its own, following [AgentNoteModel.text].
class AgentNoteField extends StatefulWidget {
  const AgentNoteField({
    super.key,
    required this.model,
    required this.onChanged,
    required this.onSend,
    this.onCopy,
    this.controller,
  });

  final AgentNoteModel model;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSend;
  final VoidCallback? onCopy;
  final TextEditingController? controller;

  @override
  State<AgentNoteField> createState() => _AgentNoteFieldState();
}

class _AgentNoteFieldState extends State<AgentNoteField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ??
      (_own ??= TextEditingController(text: widget.model.text));

  @override
  void didUpdateWidget(AgentNoteField old) {
    super.didUpdateWidget(old);
    if (widget.controller == null &&
        _own != null &&
        _own!.text != widget.model.text) {
      _own!.text = widget.model.text;
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  bool get _canSend {
    final m = widget.model;
    return widget.onSend != null &&
        m.canSend &&
        m.length > 0 &&
        !m.offline &&
        m.status != AgentNoteStatus.sending &&
        m.length <= m.limit;
  }

  void _send() {
    if (_canSend) widget.onSend!();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final l10n = context.l10n;
    if (m.status == AgentNoteStatus.unsupported) {
      return _section(context, [
        AppBanner(
          tone: AppBannerTone.neutral,
          title: l10n.chatSubagentsBannerNoteUnsupported,
        ),
      ]);
    }
    if (m.frozen || m.status == AgentNoteStatus.notControllable) {
      final missed = m.status == AgentNoteStatus.missed;
      if (m.text.isEmpty && !missed) return const SizedBox.shrink();
      return _section(context, [
        // A note that arrived too late belongs to an ended agent: say so even
        // though nothing more can be sent.
        if (missed) ...[?_banner(context), const SizedBox(height: 8)],
        if (m.text.isNotEmpty) _notSent(context),
      ], recipient: false);
    }
    final large = agentLargeText(context);
    return _section(context, [
      _field(context, large),
      const SizedBox(height: 6),
      AgentSubtleText(l10n.chatSubagentsNoteHelper),
      if (m.length >= kNoteCounterFrom) _counter(context),
      ?_banner(context),
      const SizedBox(height: 12),
      _sendButton(context),
      if (m.sentNotes.isNotEmpty) _sent(context),
    ]);
  }

  Widget _section(
    BuildContext context,
    List<Widget> children, {
    bool recipient = true,
  }) {
    final m = widget.model;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AgentSectionTitle(context.l10n.chatSubagentsNoteTitle),
        if (recipient)
          Text.rich(
            TextSpan(text: context.l10n.chatSubagentsNoteTo(m.goal)),
            // The goal is never cut at the largest text sizes.
            maxLines: agentLargeText(context) ? null : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _field(BuildContext context, bool large) {
    final m = widget.model;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final minLines = large ? 5 : 3;
    final maxLines = large ? 10 : 6;
    final readOnly = m.status == AgentNoteStatus.sending;
    final Widget field = platformChromeOf(context).isApple
        ? CupertinoTextField(
            controller: _controller,
            onChanged: widget.onChanged,
            readOnly: readOnly,
            minLines: minLines,
            maxLines: maxLines,
            placeholder: l10n.chatSubagentsNotePlaceholder,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            autofillHints: null,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            padding: const EdgeInsets.all(12),
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(10),
            ),
          )
        : TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            readOnly: readOnly,
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            autofillHints: null,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            decoration: InputDecoration(
              hintText: l10n.chatSubagentsNotePlaceholder,
              border: const OutlineInputBorder(),
            ),
          );
    return CallbackShortcuts(
      bindings: {
        for (final key in [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
        ])
          SingleActivator(
            key,
            meta: platformChromeOf(context).isApple,
            control: !platformChromeOf(context).isApple,
            includeRepeats: false,
          ): _send,
      },
      child: Semantics(label: l10n.chatSubagentsNoteLabel, child: field),
    );
  }

  Widget _counter(BuildContext context) {
    final m = widget.model;
    final over = m.length > m.limit;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (over) ...[
            ExcludeSemantics(
              child: AppIcon(AppIcons.error, size: 14, color: scheme.error),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            context.l10n.chatSubagentsNoteCounter(m.length, m.limit),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: over ? scheme.error : null,
              fontWeight: over ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _banner(BuildContext context) {
    final l10n = context.l10n;
    final (tone, title, detail) = switch (widget.model.status) {
      AgentNoteStatus.queued => (
        AppBannerTone.success,
        l10n.chatSubagentsBannerSentTitle,
        l10n.chatSubagentsBannerSentDetail,
      ),
      AgentNoteStatus.rejected => (
        AppBannerTone.warning,
        l10n.chatSubagentsBannerNoteRejected,
        '',
      ),
      AgentNoteStatus.lost => (
        AppBannerTone.warning,
        l10n.chatSubagentsBannerNoteLostTitle,
        l10n.chatSubagentsBannerNoteLostDetail,
      ),
      AgentNoteStatus.failed => (
        AppBannerTone.error,
        l10n.chatSubagentsBannerNoteFailedTitle,
        l10n.chatSubagentsBannerTryAgain,
      ),
      AgentNoteStatus.missed => (
        AppBannerTone.warning,
        l10n.chatSubagentsBannerNoteMissedTitle,
        l10n.chatSubagentsBannerNoteMissedDetail,
      ),
      _ => (AppBannerTone.neutral, '', ''),
    };
    if (title.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppBanner(tone: tone, title: title, detail: detail),
    );
  }

  Widget _sendButton(BuildContext context) {
    final l10n = context.l10n;
    final sending = widget.model.status == AgentNoteStatus.sending;
    final button = FilledButton(
      onPressed: _canSend ? _send : null,
      style: FilledButton.styleFrom(
        minimumSize: Size(0, agentTargetHeight(context)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sending) ...[
            const ExcludeSemantics(
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              sending
                  ? l10n.chatSubagentsNoteSending
                  : l10n.chatSubagentsNoteSend,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        // Full width only in the iPhone sheet (and at the largest text size);
        // inspectors and Android keep it trailing at its natural width.
        final full =
            (box.maxWidth < 480 &&
                platformChromeOf(context) == PlatformChrome.ios) ||
            agentLargeText(context);
        return full
            ? SizedBox(width: double.infinity, child: button)
            : Align(alignment: AlignmentDirectional.centerEnd, child: button);
      },
    );
  }

  Widget _notSent(BuildContext context) {
    final l10n = context.l10n;
    final h = agentTargetHeight(context);
    return AgentDashedBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatSubagentsNoteNotSent,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SelectableText(widget.model.text),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton(
              onPressed: widget.onCopy,
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, h),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              child: Text(l10n.chatSubagentsNoteCopy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sent(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgentSectionTitle(context.l10n.chatSubagentsNotesSent),
        for (final note in widget.model.sentNotes)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AgentSubtleText(note),
          ),
      ],
    ),
  );
}
