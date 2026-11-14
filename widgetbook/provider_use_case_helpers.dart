import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';

void noop() {}
void noopId(String _) {}

/// [child] at a text scale of [scale], whatever the Addons panel says.
Widget scaled(double scale, Widget child) => scale == 1
    ? child
    : Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      );

/// A settings page around [body], the way the screen will put it. A form
/// leads with Cancel (or a close button on Material) and ends with its
/// [formAction].
Widget settingsPage({
  required String Function(AppLocalizations l10n) title,
  String Function(AppLocalizations l10n)? subtitle,
  List<SettingsBarAction> Function(AppLocalizations l10n)? actions,
  SettingsFormAction? Function(AppLocalizations l10n)? formAction,
  bool cancel = false,
  required Widget body,
}) => Builder(
  builder: (context) {
    final l10n = context.l10n;
    return SettingsScaffold(
      title: title(l10n),
      subtitle: subtitle?.call(l10n),
      actions: actions?.call(l10n) ?? const [],
      formAction: formAction?.call(l10n),
      cancel: cancel,
      macCancel: cancel,
      body: body,
    );
  },
);
