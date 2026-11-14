import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/files_metrics.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import 'workspace_widget_support.dart';

/// The notice between a chat's first prompt and its reply when Hermes started
/// in another folder than the one picked: a bordered surface card with a
/// warning glyph, "**Hermes started in me instead of other.** The folder may
/// not exist on your server." and a text button, "Choose another folder".
///
/// With [profileMayUseOwnFolder] (the create was retried without
/// `cwd_explicit`) the sentence adds ", or this profile may use its own
/// folder". Not tinted and not dismissible; the warning glyph and the words
/// carry it, never colour alone. It takes the two folders' names and a
/// callback.
class FolderMismatchNotice extends StatelessWidget {
  const FolderMismatchNotice({
    super.key,
    required this.startedIn,
    required this.picked,
    this.profileMayUseOwnFolder = false,
    this.onChoose,
  });

  /// The name of the folder Hermes reports.
  final String startedIn;

  /// The name of the folder that was picked.
  final String picked;
  final bool profileMayUseOwnFolder;

  /// Opens the picker.
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final size = mac ? 13.0 : 15.0;
    final files = FilesMetrics.of(context);
    final title = l10n.workspacesMismatchTitle(
      workspaceShortName(startedIn, max: 32),
      workspaceShortName(picked, max: 32),
    );
    final detail = profileMayUseOwnFolder
        ? l10n.workspacesMismatchDetailProfile
        : l10n.workspacesMismatchDetail;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ExcludeSemantics(
                      child: AppIcon(
                        AppIcons.warning,
                        size: workspaceGlyphSize(context, size + 3),
                        color: colors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: size,
                            color: scheme.onSurface,
                          ),
                          children: [
                            TextSpan(
                              text: title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' $detail'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('folder-mismatch-choose'),
                  onPressed: onChoose,
                  style: files.buttonStyle(),
                  child: Text(l10n.workspacesMismatchChoose),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
