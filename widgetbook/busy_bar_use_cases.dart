import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/busy_bar.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

Widget _padded(Widget bar, {bool reduceMotion = false}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: fill(Padding(padding: const EdgeInsets.all(16), child: bar)),
  ),
);

WidgetbookNode busyBarNode() => WidgetbookComponent(
  name: 'BusyBar',
  useCases: [
    WidgetbookUseCase(
      name: 'Unknown amount',
      builder: (_) => _padded(const BusyBar()),
    ),
    WidgetbookUseCase(
      name: 'Unknown amount, Reduce Motion',
      builder: (_) => _padded(const BusyBar(), reduceMotion: true),
    ),
    WidgetbookUseCase(
      name: 'Determinate',
      builder: (_) => _padded(const BusyBar(value: 0.4, minHeight: 3)),
    ),
  ],
);
