import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_command_review_items.dart';

void main() {
  group('the review item of a new command server', () {
    test('has the command, the arguments and only the environment names', () {
      final item = McpCommandReviewItem.of(
        const McpNewCommandServer(
          name: 'notes',
          command: 'npx',
          args: ['-y', '/srv/my notes'],
          env: {'NOTES_TOKEN': 'secret-value', 'HOME': '/srv'},
        ),
      );

      expect(item.name, 'notes');
      expect(item.command, 'npx');
      expect(item.args, ['-y', '/srv/my notes']);
      expect(item.envNames, ['NOTES_TOKEN', 'HOME']);
      expect(item.toString(), isNot(contains('secret-value')));
    });
  });

  group('commandServersToReview', () {
    const notes = {
      'command': 'npx',
      'args': ['-y', 'pkg'],
      'env': {'K': 'v'},
    };

    List<String> names(
      Map<String, Object?> loaded,
      Map<String, Map<String, Object?>> next,
    ) => [for (final i in commandServersToReview(loaded, next)) i.name];

    test('lists a new command server', () {
      expect(names({}, {'notes': notes}), ['notes']);
    });

    test('does not list a command server that did not change', () {
      expect(
        names(
          {'notes': notes},
          {
            'notes': {...notes, 'enabled': false},
          },
        ),
        isEmpty,
      );
    });

    test('lists a server whose command changed', () {
      expect(
        names(
          {'notes': notes},
          {
            'notes': {...notes, 'command': 'bash'},
          },
        ),
        ['notes'],
      );
    });

    test('lists a server whose arguments changed', () {
      expect(
        names(
          {'notes': notes},
          {
            'notes': {
              ...notes,
              'args': ['-y', 'pkg', '--more'],
            },
          },
        ),
        ['notes'],
      );
    });

    test('lists a server whose environment value changed', () {
      expect(
        names(
          {'notes': notes},
          {
            'notes': {
              ...notes,
              'env': {'K': 'other'},
            },
          },
        ),
        ['notes'],
      );
    });

    test('lists a server whose environment name was added', () {
      expect(
        names(
          {'notes': notes},
          {
            'notes': {
              ...notes,
              'env': {'K': 'v', 'NODE_OPTIONS': '--require x'},
            },
          },
        ),
        ['notes'],
      );
    });

    test('lists a remote server that became a command server', () {
      expect(
        names(
          {
            'notes': {'url': 'https://a.test'},
          },
          {'notes': notes},
        ),
        ['notes'],
      );
    });

    test('does not list a remote server, changed or not', () {
      expect(
        names(
          {
            'a': {'url': 'https://a.test'},
          },
          {
            'a': {'url': 'https://b.test', 'headers': <String, Object?>{}},
            'b': {'url': 'https://c.test'},
          },
        ),
        isEmpty,
      );
    });

    test('does not list a removed server', () {
      expect(names({'notes': notes}, {}), isEmpty);
    });

    test('lists a server whose command is not text', () {
      final items = commandServersToReview({}, {
        'odd': {
          'command': ['bash', '-c'],
          'args': '-c echo',
        },
      });

      expect(items.single.command, '[bash, -c]');
      expect(items.single.args, ['-c echo']);
    });

    test('compares nested values, not identity', () {
      expect(
        names(
          {
            'a': {
              'command': 'x',
              'env': {
                'K': ['1', '2'],
              },
            },
          },
          {
            'a': {
              'command': 'x',
              'env': {
                'K': ['1', '2'],
              },
            },
          },
        ),
        isEmpty,
      );
    });
  });
}
