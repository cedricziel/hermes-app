import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart' show safePathText;
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/busy_bar.dart';
import '../../widgets/motion_spinner.dart';
import '../subagents/widgets/agent_widget_parts.dart' show AgentDashedBox;

final _whitespace = RegExp(r'\s+');

/// Where one image of a tool result stands.
enum ToolImageState {
  /// An address that has not been tapped: nothing was requested.
  idle,
  loading,
  loaded,

  /// A load that did not work; a tap asks again.
  failed,

  /// An `http` address: never loaded, opens in the browser.
  insecure,

  /// Over the size limit: opens in the browser.
  tooLarge,

  /// `image_generate` while it runs: a skeleton in the call's aspect ratio.
  generating,
}

/// One image as a tile: the picture once it is loaded, else what the user can
/// do with it (alt text, size and host, and a word for its state). A plain
/// model: the tap and the picture come from the body that owns the loading.
class ToolImageTile extends StatelessWidget {
  const ToolImageTile({
    super.key,
    required this.state,
    this.alt = '',
    this.name = '',
    this.size = '',
    this.host = '',
    this.image,
    this.aspectRatio = 4 / 3,
    this.onTap,
    this.onBroken,
  });

  final ToolImageState state;

  /// The page's alt text, as the web wrote it; empty for none.
  final String alt;

  /// What a screen reader calls the tile: the alt text, or "image 3 of 9".
  final String name;

  /// "800 × 800", or empty when the size is not known.
  final String size;
  final String host;

  /// The picture decoded at the width it is drawn at, so a large image never
  /// decodes in full for a thumbnail.
  final ImageProvider Function(int width)? image;
  final double aspectRatio;

  /// What a tap does in this state; null when it does nothing.
  final VoidCallback? onTap;

  /// Called once the picture turns out not to decode.
  final VoidCallback? onBroken;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final subtle = context.hermesColors.subtleText;
    final picture = state == ToolImageState.loaded && image != null;
    final meta = [size, host].where((s) => s.isNotEmpty).join(' · ');
    final shownAlt = safePathText(alt.replaceAll(_whitespace, ' ').trim());
    final label = switch (state) {
      ToolImageState.idle => l10n.chatWidgetsImageTapToLoad(host),
      ToolImageState.failed => l10n.chatWidgetsImageCouldntLoad,
      ToolImageState.insecure => l10n.chatWidgetsImageNotSecure,
      ToolImageState.tooLarge => l10n.chatWidgetsImageTooLarge,
      ToolImageState.generating => l10n.chatWidgetsImageGenerating,
      _ => '',
    };
    final icon = switch (state) {
      ToolImageState.failed => AppIcons.brokenImage,
      ToolImageState.insecure || ToolImageState.tooLarge => AppIcons.warning,
      _ => AppIcons.image,
    };
    final frame = state == ToolImageState.generating
        ? AgentDashedBox(child: _status(context, icon, label, busy: true))
        : DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: picture
                  ? LayoutBuilder(
                      builder: (context, box) => Image(
                        image: image!(
                          (box.maxWidth *
                                  MediaQuery.devicePixelRatioOf(context))
                              .round(),
                        ),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => onBroken?.call(),
                          );
                          return _status(
                            context,
                            AppIcons.brokenImage,
                            l10n.chatWidgetsImageCouldntLoad,
                          );
                        },
                      ),
                    )
                  : _status(
                      context,
                      icon,
                      label,
                      busy: state == ToolImageState.loading,
                      retry: state == ToolImageState.failed,
                    ),
            ),
          );
    // A picture keeps its ratio. A status is words, which grow with the text
    // size: its box has the ratio as a least height and never clips them.
    final box = picture
        ? AspectRatio(aspectRatio: aspectRatio, child: frame)
        : LayoutBuilder(
            builder: (context, box) => ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.maxWidth / aspectRatio,
              ),
              child: frame,
            ),
          );
    final caption = picture || state == ToolImageState.generating
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (shownAlt.isNotEmpty)
                  Text(
                    shownAlt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                if (meta.isNotEmpty)
                  Text(
                    safePathText(meta),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall!.copyWith(
                      fontWeight: FontWeight.w400,
                      color: subtle,
                    ),
                  ),
              ],
            ),
          );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [box, caption],
    );
    return Semantics(
      container: true,
      button: onTap != null,
      image: picture,
      label: [name, if (!picture) label].where((s) => s.isNotEmpty).join('. '),
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null
          ? content
          : ConstrainedBox(
              constraints: BoxConstraints(minHeight: minTapTargetOf(context)),
              child: FocusRing(
                radius: 10,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: content,
                ),
              ),
            ),
    );
  }

  Widget _status(
    BuildContext context,
    AppIconSet icon,
    String label, {
    bool busy = false,
    bool retry = false,
  }) {
    final l10n = context.l10n;
    final subtle = context.hermesColors.subtleText;
    final style = Theme.of(context).textTheme.labelSmall!
        .copyWith(fontWeight: FontWeight.w400, color: subtle);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const MotionSpinner()
            else
              AppIcon(icon, size: 20, color: subtle),
            const SizedBox(height: 4),
            if (label.isNotEmpty)
              Text(label, textAlign: TextAlign.center, style: style),
            if (retry)
              Text(
                l10n.chatWidgetsImageTapToRetry,
                textAlign: TextAlign.center,
                style: style,
              ),
            if (state == ToolImageState.generating) ...[
              const SizedBox(height: 8),
              const SizedBox(width: 120, child: BusyBar(minHeight: 2)),
            ],
          ],
        ),
      ),
    );
  }
}
