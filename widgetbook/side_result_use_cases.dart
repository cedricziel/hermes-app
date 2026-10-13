import 'package:hermes_app/src/chat/side_results/side_result_card.dart';
import 'package:hermes_app/src/chat/side_results/side_result_state.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode sideResultNode() => WidgetbookComponent(
  name: 'Side results',
  useCases: [
    for (final kind in SideResultKind.values)
      for (final open in [false, true])
        WidgetbookUseCase(
          name: '${kind.name} ${open ? 'expanded' : 'compact'}',
          builder: (_) => frame(
            SideResultCard(
              result: SideResult(
                kind: kind,
                taskId: 'fixture',
                text: 'The side task reported its answer.',
                question: kind == SideResultKind.btw ? 'What changed?' : null,
              ),
              initiallyOpen: open,
            ),
          ),
        ),
    WidgetbookUseCase(
      name: 'Empty result',
      builder: (_) => frame(
        const SideResultCard(
          result: SideResult(
            kind: SideResultKind.background,
            taskId: 'fixture',
            text: '',
          ),
          initiallyOpen: true,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Unavailable',
      builder: (_) => frame(const SideResultCard(result: null)),
    ),
    WidgetbookUseCase(
      name: 'Long result',
      builder: (_) => frame(
        SideResultCard(
          result: SideResult(
            kind: SideResultKind.btw,
            taskId: 'fixture',
            text: List.filled(
              30,
              'Reported side output wraps and scrolls on narrow windows.',
            ).join('\n'),
          ),
          initiallyOpen: true,
        ),
      ),
    ),
  ],
);
