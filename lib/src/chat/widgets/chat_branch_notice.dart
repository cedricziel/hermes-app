import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/motion_spinner.dart';

/// What the row under a branched chat's header says.
enum ChatBranchNoticeState {
  /// The original is in the loaded list: "Branched from <title>".
  title,

  /// It is not (or has no title yet): "Branched from another chat".
  unknown,

  /// A tap is reading it: "Opening the original chat…". Taps are ignored.
  opening,

  /// Hermes said it is gone: information only, not a button.
  deleted,

  /// Asking failed: "Try again"; the row stays a button.
  unreachable,
}

/// The row between a branched chat's header and its transcript: where the chat
/// came from, and a way back to the original.
///
/// One button (not in [ChatBranchNoticeState.opening] and
/// [ChatBranchNoticeState.deleted], where [onTap] is never called), at least
/// 44 pt high on iOS, 48 on Android and 32 on desktop. The title wraps to two
/// lines; the unreachable sentence keeps all its words, "Try again" last.
/// Status is the glyph and the words, never colour alone, and the row has no
/// fill, only the line under it. It takes the state, the original's title (for
/// [ChatBranchNoticeState.title]) and a callback.
class ChatBranchNotice extends StatelessWidget {
  const ChatBranchNotice({
    super.key,
    required this.state,
    this.parentTitle,
    this.onTap,
  });

  final ChatBranchNoticeState state;

  /// The original chat's title; read only in [ChatBranchNoticeState.title].
  final String? parentTitle;
  final VoidCallback? onTap;

  bool get _tappable =>
      onTap != null &&
      (state == ChatBranchNoticeState.title ||
          state == ChatBranchNoticeState.unknown ||
          state == ChatBranchNoticeState.unreachable);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final style = Theme.of(context).textTheme.bodyMedium!;
    final title = parentTitle ?? '';
    final named = state == ChatBranchNoticeState.title && title.isNotEmpty;
    final sentence = switch (state) {
      _ when named => l10n.chatWidgetsBranchNoticeFrom(title),
      ChatBranchNoticeState.title ||
      ChatBranchNoticeState.unknown => l10n.chatWidgetsBranchNoticeFromUnknown,
      ChatBranchNoticeState.opening => l10n.chatWidgetsBranchNoticeOpening,
      ChatBranchNoticeState.deleted => l10n.chatWidgetsBranchNoticeDeleted,
      ChatBranchNoticeState.unreachable =>
        l10n.chatWidgetsBranchNoticeUnreachable,
    };
    final at = named ? sentence.lastIndexOf(title) : -1;
    final muted = style.copyWith(color: colors.subtleText);
    final text = Text.rich(
      state == ChatBranchNoticeState.unreachable
          ? TextSpan(
              style: muted,
              children: [
                TextSpan(text: '$sentence '),
                TextSpan(
                  text: l10n.chatWidgetsBranchNoticeRetry,
                  style: style.copyWith(
                    color: colors.link,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : at < 0
          ? TextSpan(text: sentence, style: muted)
          : TextSpan(
              style: muted,
              children: [
                TextSpan(text: sentence.substring(0, at)),
                TextSpan(
                  text: title,
                  style: style.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(text: sentence.substring(at + title.length)),
              ],
            ),
      // An ellipsis ends a paragraph after one line unless maxLines is set.
      maxLines: state == ChatBranchNoticeState.unreachable ? null : 2,
      overflow: state == ChatBranchNoticeState.unreachable
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
    );
    final leading = switch (state) {
      ChatBranchNoticeState.deleted => AppIcon(
        AppIcons.info,
        size: 16,
        color: colors.subtleText,
      ),
      ChatBranchNoticeState.unreachable => AppIcon(
        AppIcons.warning,
        size: 16,
        color: colors.warning,
      ),
      _ => null,
    };
    final trailing = switch (state) {
      ChatBranchNoticeState.opening => const MotionSpinner(),
      ChatBranchNoticeState.title || ChatBranchNoticeState.unknown => AppIcon(
        AppIcons.chevronRight,
        size: 16,
        color: colors.subtleText,
      ),
      ChatBranchNoticeState.unreachable ||
      ChatBranchNoticeState.deleted => null,
    };
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minTapTargetOf(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            if (leading != null) ...[
              ExcludeSemantics(child: leading),
              const SizedBox(width: 8),
            ],
            Expanded(child: text),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              ExcludeSemantics(child: trailing),
            ],
          ],
        ),
      ),
    );
    final row = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: _tappable
          ? FocusRing(
              radius: 6,
              child: InkWell(onTap: onTap, child: content),
            )
          : content,
    );
    final label = switch (state) {
      _ when named => l10n.chatWidgetsBranchNoticeSemantics(title),
      ChatBranchNoticeState.unreachable =>
        '$sentence ${l10n.chatWidgetsBranchNoticeRetry}',
      _ => sentence,
    };
    return Semantics(
      container: true,
      button: _tappable,
      label: label,
      excludeSemantics: true,
      onTap: _tappable ? onTap : null,
      child: row,
    );
  }
}
