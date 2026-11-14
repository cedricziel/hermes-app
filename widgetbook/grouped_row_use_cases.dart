import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

Widget _at(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: frame(child),
  ),
);

const _rows = GroupedSection(
  header: 'Messaging',
  children: [
    GroupedRow(title: 'Telegram', value: 'Set up', onTap: _noop),
    GroupedRow(title: 'Discord', value: 'Off', onTap: _noop),
    GroupedRow(
      title: 'State',
      value: 'Running, some channels offline',
      subtitle: 'Messaging gateway',
    ),
  ],
);

void _noop() {}

/// A value sits beside its title while it fits; above the default text size
/// one that does not fit moves under the title, ahead of the subtitle.
WidgetbookNode groupedRowValueNode() => WidgetbookComponent(
  name: 'GroupedRow value',
  useCases: [
    for (final (name, scale) in [
      ('Default text', 1.0),
      ('1.5x text', 1.5),
      ('2x text', 2.0),
    ])
      WidgetbookUseCase(name: name, builder: (_) => _at(scale, _rows)),
  ],
);
