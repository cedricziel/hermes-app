import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

void main() {
  SourceFile file(String source) => SourceFile('lib/x.dart', source);

  test('comments are blanked in both views, lengths and lines kept', () {
    final f = file('a(); // Dio(\n/* IconButton(\n */ b();\n');
    expect(f.code.length, f.raw.length);
    expect(f.text, isNot(contains('Dio(')));
    expect(f.text, isNot(contains('IconButton(')));
    expect(f.code, contains('a();'));
    expect(f.code, contains('b();'));
    expect(f.lineOf(f.raw.indexOf('b();')), 3);
  });

  test('block comments nest', () {
    final f = file('/* a /* b */ Dio( */ final c = Dio();');
    expect('Dio('.allMatches(f.code), hasLength(1));
  });

  test('string contents count in text but not in code', () {
    final f = file("final a = 'hermes://new'; final b = Dio();");
    expect(f.text, contains('hermes://new'));
    expect(f.code, isNot(contains('hermes://')));
    expect(f.code, contains('Dio('));
  });

  test('a comment marker inside a string is not a comment', () {
    final f = file("final a = 'http://x'; final b = Dio();");
    expect(f.text, contains('http://x'));
    expect(f.code, contains('Dio('));
  });

  test('interpolated code stays visible in the code view', () {
    final f = file(r"final a = 'x ${Dio()} y $name';");
    expect(f.code, contains('Dio('));
    expect(f.code, isNot(contains('name')));
    expect(f.text, contains(r'$name'));
  });

  test('raw and triple-quoted strings', () {
    final f = file('const b = r"\\\$Dio(";\nfinal d = """\nDio(\n""";\nDio();');
    expect('Dio('.allMatches(f.code), hasLength(1));
    expect(f.text, contains('Dio('));
  });

  test('isAllowed matches files and directory prefixes', () {
    expect(isAllowed('lib/a/b.dart', ['lib/a/']), isTrue);
    expect(isAllowed('lib/a/b.dart', ['lib/a/b.dart']), isTrue);
    expect(isAllowed('lib/ab.dart', ['lib/a/']), isFalse);
  });
}
