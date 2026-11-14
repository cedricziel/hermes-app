import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import 'closes_with.dart';

enum LogLevelFilter {
  all,
  warnings,
  errors;

  String label(AppLocalizations l10n) => switch (this) {
    all => l10n.serverCareLogLevelFilterAll,
    warnings => l10n.serverCareLogLevelFilterWarnings,
    errors => l10n.serverCareLogLevelFilterErrors,
  };
}

/// A pill under the search field that shows the chosen level and opens a menu
/// of the three choices. It is not the search field's own filter menu, so the
/// choice stays visible.
class LogLevelMenuButton extends StatelessWidget {
  const LogLevelMenuButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.closeWith,
  });

  final LogLevelFilter value;
  final ValueChanged<LogLevelFilter> onChanged;

  /// Closes the open menu when it fires.
  final Listenable? closeWith;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final minHeight = platformChromeOf(context) == PlatformChrome.material
        ? 48.0
        : kAppleMinTapTarget;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: l10n.serverCareLogLevelMenuLabel(value.label(l10n)),
        child: AdaptivePopupMenuButton<LogLevelFilter>(
          tooltip: '',
          position: PopupMenuPosition.under,
          onSelected: onChanged,
          itemBuilder: (context) => [
            for (final option in LogLevelFilter.values)
              CheckedPopupMenuItem<LogLevelFilter>(
                value: option,
                checked: option == value,
                child: ClosesWith(
                  closer: closeWith,
                  child: Text(option.label(l10n)),
                ),
              ),
          ],
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: StadiumBorder(side: BorderSide(color: scheme.outline)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Flexible(
                        child: Text(
                          value.label(l10n),
                          style: TextStyle(color: scheme.onSurface),
                        ),
                      ),
                      AppIcon(
                        AppIcons.expandMore,
                        size: 18,
                        color: scheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
