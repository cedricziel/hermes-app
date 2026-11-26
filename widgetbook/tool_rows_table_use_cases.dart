import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/rows_fixtures.dart';
import 'frame.dart';

Widget _card(ToolCall call, {double width = 480}) =>
    frame(ToolCallCard(call: call, initiallyOpen: true), maxWidth: width);

ToolCall _search(int count) =>
    rowsCall(densifiedAnswer(manyMatches(count), totalCount: count));

List<Map<String, Object?>> _services(int count) => [
  for (var i = 0; i < count; i++)
    {
      'id': 1000 + i,
      'name': 'worker-$i',
      'cpu': i * 1.5,
      'healthy': i.isEven,
      'owner': i % 3 == 0 ? null : 'team-${i % 3}',
    },
];

Widget _german(Widget child) => Builder(
  builder: (context) => Localizations.override(
    context: context,
    locale: const Locale('de'),
    child: child,
  ),
);

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

WidgetbookNode toolRowsTableNode() => WidgetbookFolder(
  name: 'Rows table',
  children: [
    WidgetbookComponent(
      name: 'RowsToolBody',
      useCases: [
        WidgetbookUseCase(
          name: 'Search matches',
          builder: (_) => _card(_search(12)),
        ),
        ...onEachPlatform('Search matches', (_) => _card(_search(12))),
        WidgetbookUseCase(
          name: 'Three matches, a list',
          builder: (_) =>
              _card(rowsCall({'total_count': 3, 'matches': matchRows(3)})),
        ),
        WidgetbookUseCase(
          name: '50 rows and Show 50 more',
          builder: (_) => _card(_search(120)),
        ),
        WidgetbookUseCase(
          name: 'The 500 cap',
          builder: (_) => _card(_search(620)),
        ),
        WidgetbookUseCase(
          name: 'Eight columns and more',
          builder: (_) => _card(
            rowsCall([
              {for (var i = 0; i < 11; i++) 'column_$i': 'value $i'},
              {for (var i = 0; i < 11; i++) 'column_$i': 'second $i'},
            ], name: 'list_things'),
            width: 720,
          ),
        ),
        WidgetbookUseCase(
          name: 'Nulls, booleans and numbers',
          builder: (_) => _card(rowsCall(_services(6), name: 'list_services')),
        ),
        WidgetbookUseCase(
          name: 'A long cell',
          builder: (_) => _card(
            rowsCall({
              'total_count': 2,
              'matches': [
                {
                  'path': 'lib/src/some/very/deeply/nested/folder/file.dart',
                  'line': 42,
                  'content': 'x' * 400,
                },
                {'path': 'lib/main.dart', 'line': 7, 'content': 'short'},
              ],
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'Wide enough to scroll on a phone',
          builder: (_) => _card(_search(12), width: 360),
        ),
        WidgetbookUseCase(
          name: 'Fits on a desktop',
          builder: (_) => _card(_search(12), width: 720),
        ),
        WidgetbookUseCase(
          name: 'No matches',
          builder: (_) => _card(rowsCall({'total_count': 0})),
        ),
        WidgetbookUseCase(
          name: 'A search that stopped early',
          builder: (_) => _card(
            rowsCall(
              densifiedAnswer(
                manyMatches(50),
                totalCount: 212,
                extra: {
                  'truncated': true,
                  'total_count_is_lower_bound': true,
                  '_omitted':
                      '2 result(s) omitted because they target credential, '
                      'token, cache, or secret-bearing environment files.',
                },
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Everything held back',
          builder: (_) => _card(
            rowsCall({
              'total_count': 3,
              '_omitted':
                  '3 result(s) omitted because they target credential, '
                  'token, cache, or secret-bearing environment files.',
            }),
          ),
        ),
        WidgetbookUseCase(
          name: 'A nested value (the fallback)',
          builder: (_) => _card(
            rowsCall(
              [
                {
                  'id': 1,
                  'tags': ['a', 'b'],
                },
              ],
              name: 'list_things',
              text: '[{"id":1,"tags":["a","b"]}]',
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Running',
          builder: (_) => _card(rowsCall(null, status: ToolCallStatus.running)),
        ),
        WidgetbookUseCase(
          name: 'German',
          builder: (_) => _german(_card(_search(120))),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _scaled(3, _card(_search(12))),
        ),
      ],
    ),
  ],
);
