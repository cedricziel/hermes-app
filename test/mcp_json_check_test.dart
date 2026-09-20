import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/mcp/mcp_json_check.dart';

void main() {
  McpJsonInvalid invalid(String text) =>
      checkMcpServersJson(text) as McpJsonInvalid;

  test('accepts an object of objects', () {
    final check = checkMcpServersJson('''
{
  "a": {"url": "https://a.test", "timeout": 5, "headers": {"K": "v"}},
  "b": {"command": "true", "args": []}
}''');

    expect(
      check,
      isA<McpJsonValid>().having((c) => c.servers.keys, 'names', ['a', 'b']),
    );
    expect((check as McpJsonValid).servers['a']!['timeout'], 5);
  });

  test('accepts an empty object', () {
    expect(checkMcpServersJson('{}'), isA<McpJsonValid>());
    expect(checkMcpServersJson('  {\n}\n'), isA<McpJsonValid>());
  });

  test('names the line of a syntax error', () {
    final check = invalid('{\n  "a": {\n    "url": "x"\n    "b": 1\n  }\n}');

    expect(check.message, startsWith('Line 4: '));
  });

  test('names line 1 for an error on the first line', () {
    expect(invalid('{"a": ').message, startsWith('Line 1: '));
  });

  test('treats empty text as an error', () {
    expect(invalid('').message, startsWith('Line 1: '));
  });

  test('rejects a top level that is not an object', () {
    expect(invalid('[]').message, contains('must be an object'));
    expect(invalid('"x"').message, contains('must be an object'));
  });

  test('rejects a server that is not an object', () {
    expect(invalid('{"a": "text"}').message, contains('"a" must be an object'));
    expect(invalid('{"a": null}').message, contains('"a" must be an object'));
    expect(invalid('{"a": []}').message, contains('"a" must be an object'));
  });

  test('does not put the text into the message', () {
    expect(
      invalid('{"a": "super-secret-value" "b": 1}').message,
      isNot(contains('super-secret-value')),
    );
  });
}
