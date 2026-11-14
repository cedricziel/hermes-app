import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_popup_menu_button.dart';

enum LogLevelFilter {
  all('All levels'),
  warnings('Warnings and errors'),
  errors('Errors only');

  const LogLevelFilter(this.label);

  final String label;
}

/// A pill under the search field that shows the chosen level and opens a menu
/// of the three choices. It is not the search field's own filter menu, so the
/// choice stays visible.
class LogLevelMenuButton extends StatelessWidget {
  const LogLevelMenuButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LogLevelFilter value;
  final ValueChanged<LogLevelFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minHeight = platformChromeOf(context) == PlatformChrome.material
        ? 48.0
        : kAppleMinTapTarget;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: 'Level, ${value.label}',
        child: AdaptivePopupMenuButton<LogLevelFilter>(
          tooltip: '',
          position: PopupMenuPosition.under,
          onSelected: onChanged,
          itemBuilder: (context) => [
            for (final option in LogLevelFilter.values)
              CheckedPopupMenuItem<LogLevelFilter>(
                value: option,
                checked: option == value,
                child: Text(option.label),
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
                          value.label,
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
