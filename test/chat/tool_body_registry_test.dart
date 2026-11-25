import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/tool_body_registry.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_bodies.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart';

class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

ToolCall _call(String name, {Object? resultData, String diff = ''}) =>
    ToolCall(name: name, summary: '', resultData: resultData, diff: diff);

Widget _host(Widget child) => MaterialApp(
  theme: buildHermesLightTheme(),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('ToolBodyRegistry', () {
    test('a new entry adds a body for its tool with no other edit', () {
      final registry = ToolBodyRegistry([
        ...standardToolBodyEntries,
        ToolBodyEntry(names: {'sql_query'}, build: (_) => const _Probe('rows')),
      ]);

      expect(registry.bodyFor(_call('sql_query')), isA<_Probe>());
      expect(toolCallBody(_call('sql_query')), isNull);
      expect(registry.bodyFor(_call('web_search')), isNull);
    });

    test('a result-shape predicate narrows an entry', () {
      final registry = ToolBodyRegistry([
        ToolBodyEntry(
          names: {'sql_query'},
          matches: (call) => switch (call.resultData) {
            {'rows': _} => true,
            _ => false,
          },
          build: (_) => const _Probe('rows'),
        ),
      ]);

      expect(
        registry.bodyFor(_call('sql_query', resultData: {'rows': []})),
        isA<_Probe>(),
      );
      expect(registry.bodyFor(_call('sql_query', resultData: 'text')), isNull);
    });

    test('a call that changed a file shows its diff before any entry', () {
      final registry = ToolBodyRegistry([
        ...standardToolBodyEntries,
        ToolBodyEntry(names: {'patch'}, build: (_) => const _Probe('other')),
      ]);

      expect(
        registry.bodyFor(_call('patch', diff: '@@ -1 +1 @@\n-a\n+b')),
        isA<ToolDiffBody>(),
      );
      expect(
        registry.bodyFor(_call('terminal', resultData: {'diff': '-a\n+b'})),
        isA<ToolDiffBody>(),
      );
    });

    test(
      'a builder that throws gives no body, and later entries still run',
      () {
        final registry = ToolBodyRegistry([
          ToolBodyEntry(
            names: {'sql_query'},
            build: (_) => throw const FormatException('malformed'),
          ),
          ToolBodyEntry(
            names: {'sql_query'},
            build: (_) => const _Probe('next'),
          ),
        ]);

        expect(registry.bodyFor(_call('sql_query')), isA<_Probe>());
        expect(
          ToolBodyRegistry([
            ToolBodyEntry(
              names: {'sql_query'},
              build: (_) => throw StateError('boom'),
            ),
          ]).bodyFor(_call('sql_query')),
          isNull,
        );
      },
    );

    test('a predicate that throws counts as no match', () {
      final registry = ToolBodyRegistry([
        ToolBodyEntry(
          names: {'sql_query'},
          matches: (_) => throw StateError('boom'),
          build: (_) => const _Probe('never'),
        ),
      ]);

      expect(registry.bodyFor(_call('sql_query')), isNull);
    });
  });

  group('standard entries', () {
    test('a malformed result falls back, a well-formed one gets its body', () {
      expect(toolCallBody(_call('web_search', resultData: 'nope')), isNull);
      expect(toolCallBody(_call('todo', resultData: {'todos': 7})), isNull);
      expect(toolCallBody(_call('terminal')), isNull);
      expect(
        toolCallBody(
          _call(
            'web_search',
            resultData: {
              'data': {'web': []},
            },
          ),
        ),
        isA<WebSearchToolBody>(),
      );
    });

    testWidgets('the card shows the generic input and result when a builder '
        'throws', (tester) async {
      await tester.pumpWidget(
        _host(
          ToolCallCard(
            call: const ToolCall(
              name: 'sql_query',
              summary: '',
              result: 'plain text',
            ),
            initiallyOpen: true,
            registry: ToolBodyRegistry([
              ToolBodyEntry(
                names: {'sql_query'},
                build: (_) => throw const FormatException('malformed'),
              ),
            ]),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Result'), findsOneWidget);
    });

    testWidgets('the card shows the generic input and result for a malformed '
        'result', (tester) async {
      await tester.pumpWidget(
        _host(
          const ToolCallCard(
            call: ToolCall(
              name: 'web_search',
              summary: '',
              result: 'plain text',
              resultData: 'not a map',
            ),
            initiallyOpen: true,
          ),
        ),
      );

      expect(find.byType(WebSearchToolBody), findsNothing);
      expect(find.text('Result'), findsOneWidget);
    });
  });
}
