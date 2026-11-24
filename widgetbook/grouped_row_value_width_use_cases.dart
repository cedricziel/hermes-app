import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'platform_theme.dart';

/// How [GroupedValueRow], [GroupedMenuRow] and [GroupedSwitchRow] share a
/// narrow row between the title and the value, at the widths where they were
/// measured to overflow. The theme addon gives light and dark.
WidgetbookNode groupedRowValueWidthNode() => WidgetbookComponent(
  name: 'Grouped row value width',
  useCases: [
    for (final scale in [1.0, 1.5, 3.0])
      _useCase(
        'Mac dialog row, 246 px',
        TargetPlatform.macOS,
        rowWidth: 246,
        window: 1280,
        scale: scale,
      ),
    for (final window in [800.0, 1200.0])
      for (final scale in [1.0, 1.5])
        _useCase(
          'iOS dialog row, 320 px in a ${window.toInt()} px window',
          TargetPlatform.iOS,
          rowWidth: 320,
          window: window,
          scale: scale,
        ),
    _useCase(
      'Mac dialog row, 246 px, long title and "Hermes Standard"',
      TargetPlatform.macOS,
      rowWidth: 246,
      window: 1280,
      scale: 1,
      child: GroupedValueRow(
        title: 'Bei Abschluss benachrichtigen',
        value: 'Hermes Standard',
        onTap: () {},
      ),
    ),
    for (final scale in [1.0, 1.5])
      _useCase(
        'iPhone list, 390 px',
        TargetPlatform.iOS,
        rowWidth: 358,
        window: 390,
        scale: scale,
      ),
    for (final scale in [1.0, 1.5])
      _useCase(
        'Android list, 412 px',
        TargetPlatform.android,
        rowWidth: 384,
        window: 412,
        scale: scale,
      ),
  ],
);

WidgetbookUseCase _useCase(
  String name,
  TargetPlatform platform, {
  required double rowWidth,
  required double window,
  required double scale,
  Widget child = const _Rows(),
}) => WidgetbookUseCase(
  name:
      '$name, ${scale == 1
          ? "1x"
          : scale == 3
          ? "3x"
          : "large text"}',
  builder: (context) => Theme(
    data: platformTheme(context, platform),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(size: Size(window, 800), textScaler: TextScaler.linear(scale)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: rowWidth, child: child),
        ),
      ),
    ),
  ),
);

const _longValue = 'Aktives Profil (default) mit weiteren Einstellungen';

class _Rows extends StatelessWidget {
  const _Rows();

  @override
  Widget build(BuildContext context) => GroupedSection(
    children: [
      GroupedValueRow(
        title: 'Aktives Profil (default)',
        value: _longValue,
        onTap: () {},
      ),
      GroupedValueRow(
        title: 'Bei Abschluss benachrichtigen',
        value: 'Hermes Standard',
        onTap: () {},
      ),
      GroupedValueRow(title: 'Profil', value: 'Hermes', onTap: () {}),
      GroupedMenuRow<String>(
        title: 'Aktives Profil',
        options: const [_longValue, 'Hermes'],
        labelOf: (option) => option,
        selected: _longValue,
        onSelected: (_) {},
      ),
      GroupedMenuRow<String>(
        title: 'Profil',
        options: const ['Hermes', 'Coder'],
        labelOf: (option) => option,
        selected: 'Hermes',
        onSelected: (_) {},
      ),
      GroupedMenuRow<String>(
        title: 'Orchestrator-Profil',
        options: const ['Aktives Profil (default)', 'Hermes'],
        labelOf: (option) => option,
        selected: 'Aktives Profil (default)',
        onSelected: (_) {},
      ),
      GroupedMenuRow<String>(
        title: 'Standardmäßig zuständig',
        options: const ['Niemand', 'coder'],
        labelOf: (option) => option,
        selected: 'Niemand',
        onSelected: (_) {},
      ),
      GroupedSwitchRow(
        title: 'Automatisch Unteraufgaben erstellen',
        value: true,
        onChanged: (_) {},
      ),
      GroupedSwitchRow(
        title: 'Bei Abschluss benachrichtigen',
        value: false,
        onChanged: (_) {},
      ),
      GroupedSwitchRow(title: 'Hinweise', value: true, onChanged: (_) {}),
    ],
  );
}
