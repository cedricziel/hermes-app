import 'package:flutter_test/flutter_test.dart';

import '../../tool/style_score/allowlist.dart';
import '../../tool/style_score/report.dart';
import '../../tool/style_score/scanner.dart';

const _imports = "import 'package:flutter/material.dart';\n";

/// The categories found in [body], one entry per finding.
List<String> scan(
  String body, {
  String path = 'lib/src/chat/x.dart',
  String imports = _imports,
}) => [for (final f in scanSource('$imports$body', path: path)) f.category];

void main() {
  group('a.color', () {
    test('counts constructors and Colors members', () {
      expect(scan('final a = Color(0xFF112233);'), ['a.color']);
      expect(scan('final a = const Color(0xFF112233);'), ['a.color']);
      expect(scan('final a = Color.fromARGB(255, 1, 2, 3);'), ['a.color']);
      expect(scan('final a = Color.fromRGBO(1, 2, 3, 1);'), ['a.color']);
      expect(scan('final a = Colors.red;'), ['a.color']);
      expect(scan('final a = Colors.red.shade50;'), ['a.color']);
      expect(scan('final a = Colors.black54;'), ['a.color']);
    });

    test('ignores transparent and theme colours', () {
      expect(scan('final a = Colors.transparent;'), isEmpty);
      expect(scan('final a = scheme.primary;'), isEmpty);
      expect(scan('final a = MyColors.red;'), isEmpty);
    });
  });

  group('a.spacing', () {
    test('counts off-scale literals in every EdgeInsets constructor', () {
      expect(scan('final a = EdgeInsets.all(10);'), ['a.spacing']);
      expect(
        scan('final a = EdgeInsets.symmetric(horizontal: 14, vertical: 8);'),
        ['a.spacing'],
      );
      expect(scan('final a = EdgeInsets.only(left: 5, top: 7);'), [
        'a.spacing',
        'a.spacing',
      ]);
      expect(scan('final a = EdgeInsets.fromLTRB(16, 3, 16, 0);'), [
        'a.spacing',
      ]);
      expect(scan('final a = EdgeInsetsDirectional.only(start: 10);'), [
        'a.spacing',
      ]);
      expect(scan('final a = EdgeInsets.all(8.5);'), ['a.spacing']);
    });

    test('ignores on-scale values and non-literals', () {
      expect(scan('final a = EdgeInsets.all(8);'), isEmpty);
      expect(scan('final a = EdgeInsets.all(8.0);'), isEmpty);
      expect(
        scan('final a = EdgeInsets.symmetric(horizontal: 16, vertical: 0);'),
        isEmpty,
      );
      expect(scan('final a = EdgeInsets.all(gap);'), isEmpty);
      expect(scan('final a = EdgeInsets.zero;'), isEmpty);
    });

    test('counts a childless SizedBox gap in a list, not a sized box', () {
      expect(scan('final a = [SizedBox(height: 10)];'), ['a.spacing']);
      expect(scan('final a = [const SizedBox(width: 3)];'), ['a.spacing']);
      expect(scan('final a = [SizedBox(height: 10, child: x)];'), isEmpty);
      expect(scan('final a = [SizedBox(height: 8)];'), isEmpty);
      expect(scan('final a = SizedBox(height: 120);'), isEmpty);
      expect(scan('final a = [cond ? SizedBox(height: 10) : x];'), [
        'a.spacing',
      ]);
    });

    test('counts separatorBuilder gaps and SizedBox.square in a list', () {
      expect(
        scan(
          'final a = ListView.separated(separatorBuilder: (c, i) => const SizedBox(height: 10));',
        ),
        ['a.spacing'],
      );
      expect(
        scan(
          'final a = Foo(separatorBuilder: (c, i) { return SizedBox(width: 3); });',
        ),
        ['a.spacing'],
      );
      expect(
        scan('final a = Foo(separatorBuilder: (c, i) => SizedBox(height: 8));'),
        isEmpty,
      );
      expect(
        scan(
          'final a = Foo(separatorBuilder: (c, i) => SizedBox(height: 10, child: x));',
        ),
        isEmpty,
      );
      expect(
        scan('final a = Foo(itemBuilder: (c, i) => SizedBox(height: 10));'),
        isEmpty,
      );
      expect(scan('final a = [SizedBox.square(dimension: 10)];'), [
        'a.spacing',
      ]);
      expect(scan('final a = [SizedBox.square(dimension: 8)];'), isEmpty);
      expect(
        scan('final a = [SizedBox.square(dimension: 10, child: x)];'),
        isEmpty,
      );
      expect(scan('final a = SizedBox.square(dimension: 10);'), isEmpty);
    });

    test('counts Gap and spacing arguments', () {
      expect(scan('final a = Gap(10);'), ['a.spacing']);
      expect(scan('final a = Gap(12);'), isEmpty);
      expect(scan('final a = Wrap(spacing: 10, runSpacing: 4);'), [
        'a.spacing',
      ]);
    });
  });

  group('a.radius', () {
    test('counts off-token radii', () {
      expect(scan('final a = BorderRadius.circular(8);'), ['a.radius']);
      expect(scan('final a = Radius.circular(12);'), ['a.radius']);
      expect(scan('final a = Foo(borderRadius: 9);'), ['a.radius']);
      expect(
        scan('final a = BorderRadius.only(topLeft: Radius.circular(4));'),
        ['a.radius'],
      );
    });

    test('0 is on scale, a pill is 999 or more', () {
      expect(scan('final a = BorderRadius.circular(0);'), isEmpty);
      expect(scan('final a = BorderRadius.circular(9999);'), isEmpty);
      expect(scan('final a = Radius.circular(1000);'), isEmpty);
      expect(scan('final a = BorderRadius.circular(998);'), ['a.radius']);
    });

    test('ignores token radii and constants', () {
      expect(scan('final a = BorderRadius.circular(14);'), isEmpty);
      expect(scan('final a = BorderRadius.circular(999);'), isEmpty);
      expect(scan('final a = BorderRadius.circular(kHermesRadius);'), isEmpty);
      expect(scan('final a = Radius.circular(6);'), isEmpty);
    });
  });

  group('a.font', () {
    test('counts any numeric fontSize', () {
      expect(scan('final a = TextStyle(fontSize: 13);'), ['a.font']);
      expect(scan('final a = s.copyWith(fontSize: 11.5);'), ['a.font']);
    });

    test('ignores computed sizes', () {
      expect(scan('final a = TextStyle(fontSize: base);'), isEmpty);
      expect(
        scan('final a = TextStyle(fontWeight: FontWeight.w600);'),
        isEmpty,
      );
    });
  });

  group('a.duration', () {
    test('counts animation durations only', () {
      expect(
        scan('final a = AnimatedFoo(duration: Duration(milliseconds: 200));'),
        ['a.duration'],
      );
      expect(
        scan(
          'final a = Foo(reverseDuration: const Duration(milliseconds: 90));',
        ),
        ['a.duration'],
      );
      expect(
        scan('final a = Future.delayed(Duration(milliseconds: 200));'),
        isEmpty,
      );
      expect(scan('final a = Foo(duration: someDuration);'), isEmpty);
    });

    test('is informational, not part of S', () {
      final findings = scanSource(
        '${_imports}final a = Foo(duration: Duration(milliseconds: 200));',
        path: 'lib/src/chat/x.dart',
      );
      expect(StyleReport(findings).total, 0);
      expect(StyleReport(findings).informational['a.duration'], 1);
    });
  });

  group('a.font roles', () {
    test('splits role and off-role sizes', () {
      List<String?> tags(String body) => [
        for (final f in scanSource('$_imports$body', path: 'lib/x.dart')) f.tag,
      ];
      expect(tags('final a = TextStyle(fontSize: 13);'), ['font.role']);
      expect(tags('final a = TextStyle(fontSize: 12.5);'), ['font.offRole']);
      expect(tags('final a = TextStyle(fontSize: 11);'), ['font.offRole']);
    });
  });

  group('a.elevation', () {
    test('counts non-zero elevation and BoxShadow', () {
      expect(scan('final a = Material(elevation: 6);'), ['a.elevation']);
      expect(scan('final a = BoxShadow(blurRadius: 4);'), ['a.elevation']);
      expect(scan('final a = Material(elevation: 0);'), isEmpty);
      expect(scan('final a = Material(elevation: e);'), isEmpty);
    });
  });

  group('a.iconSize', () {
    test('is informational', () {
      expect(scan('final a = Icon(x, size: 20);'), ['a.iconSize']);
      expect(scan('final a = AppIcon(x, size: 18);'), ['a.iconSize']);
      expect(scan('final a = IconButton(iconSize: 22);'), ['a.iconSize']);
      expect(scan('final a = SizedBox(size: 20);'), isEmpty);
      expect(
        StyleReport(
          scanSource(
            '${_imports}final a = Icon(x, size: 20);',
            path: 'lib/x.dart',
          ),
        ).total,
        0,
      );
    });
  });

  group('b.dialog', () {
    test('counts direct dialogs and sheets', () {
      expect(scan('void f() { showDialog(context: c, builder: b); }'), [
        'b.dialog',
      ]);
      expect(scan('void f() { showModalBottomSheet(context: c); }'), [
        'b.dialog',
      ]);
      expect(scan('void f() { showCupertinoDialog(context: c); }'), [
        'b.dialog',
      ]);
      expect(scan('void f() { showCupertinoModalPopup(context: c); }'), [
        'b.dialog',
      ]);
      expect(scan('void f() { showGeneralDialog(context: c); }'), ['b.dialog']);
      expect(scan('final a = AlertDialog(title: x);'), ['b.dialog']);
      expect(scan('final a = CupertinoAlertDialog();'), ['b.dialog']);
    });

    test('ignores the shared helpers and the files that implement them', () {
      expect(
        scan('void f() { showAppDialog(context: c, builder: b); }'),
        isEmpty,
      );
      expect(scan('void f() { showAdaptiveSheet(c, builder: b); }'), isEmpty);
      expect(
        scan(
          'void f() { showDialog(context: c); }',
          path: 'lib/src/widgets/adaptive_sheet.dart',
        ),
        isEmpty,
      );
      expect(
        scan(
          'void f() { showAdaptiveDialog(context: c); }',
          path: 'lib/src/widgets/dialog_presentation.dart',
        ),
        isEmpty,
      );
    });
  });

  group('c.adaptive', () {
    test('counts plain controls', () {
      for (final w in [
        'Switch(value: v, onChanged: f)',
        'Slider(value: v, onChanged: f)',
        'Checkbox(value: v, onChanged: f)',
        'CircularProgressIndicator()',
        'Radio<int>(value: 1)',
        'SwitchListTile(value: v, onChanged: f)',
        'CheckboxListTile(value: v, onChanged: f)',
        'RadioListTile<int>(value: 1)',
      ]) {
        expect(scan('final a = $w;'), ['c.adaptive'], reason: w);
        expect(scan('final a = const $w;'), ['c.adaptive'], reason: 'const $w');
      }
    });

    test('ignores .adaptive constructors and wrappers', () {
      expect(
        scan('final a = Switch.adaptive(value: v, onChanged: f);'),
        isEmpty,
      );
      expect(
        scan('final a = Slider.adaptive(value: v, onChanged: f);'),
        isEmpty,
      );
      expect(scan('final a = CircularProgressIndicator.adaptive();'), isEmpty);
      expect(scan('final a = GroupedSwitch(value: v);'), isEmpty);
    });
  });

  group('const and prefixed forms', () {
    const pre = "import 'package:flutter/material.dart' as m;\n";
    int count(String body, String cat, {String imports = _imports}) =>
        scan(body, imports: imports).where((c) => c == cat).length;

    test('const named constructors count like the plain ones', () {
      expect(scan('final a = const EdgeInsets.all(7);'), ['a.spacing']);
      expect(scan('final a = const EdgeInsets.symmetric(horizontal: 7);'), [
        'a.spacing',
      ]);
      expect(scan('final a = const EdgeInsets.all(8);'), isEmpty);
      expect(scan('final a = const BorderRadius.circular(7);'), ['a.radius']);
      expect(scan('final a = const BorderRadius.circular(14);'), isEmpty);
      expect(scan('final a = const Radius.circular(7);'), ['a.radius']);
      expect(scan('final a = [const SizedBox.square(dimension: 7)];'), [
        'a.spacing',
      ]);
      expect(scan('final a = const Color.fromARGB(1, 2, 3, 4);'), ['a.color']);
      expect(scan('final a = const Color(0xFF000000);'), ['a.color']);
      expect(scan('final a = const Switch(value: true);'), ['c.adaptive']);
      expect(scan('final a = const BoxShadow(blurRadius: 4);'), [
        'a.elevation',
      ]);
      expect(scan('final a = const AlertDialog();'), ['b.dialog']);
    });

    test('prefixed constructors and calls count for every rule', () {
      expect(
        count('final a = m.EdgeInsets.all(7);', 'a.spacing', imports: pre),
        1,
      );
      expect(
        count(
          'final a = const m.EdgeInsets.all(7);',
          'a.spacing',
          imports: pre,
        ),
        1,
      );
      expect(
        count(
          'final a = [m.SizedBox.square(dimension: 7)];',
          'a.spacing',
          imports: pre,
        ),
        1,
      );
      expect(
        count(
          'final a = [const m.SizedBox.square(dimension: 7)];',
          'a.spacing',
          imports: pre,
        ),
        1,
      );
      expect(
        count(
          'final a = [const m.SizedBox(width: 7)];',
          'a.spacing',
          imports: pre,
        ),
        1,
      );
      expect(
        count(
          'final a = m.BorderRadius.circular(7);',
          'a.radius',
          imports: pre,
        ),
        1,
      );
      expect(
        count(
          'final a = const m.BorderRadius.circular(7);',
          'a.radius',
          imports: pre,
        ),
        1,
      );
      expect(
        count(
          'final a = const m.Color.fromARGB(1, 2, 3, 4);',
          'a.color',
          imports: pre,
        ),
        1,
      );
      expect(count('final a = m.Color(0xFF);', 'a.color', imports: pre), 1);
      expect(
        count(
          'final a = const m.Switch(value: true);',
          'c.adaptive',
          imports: pre,
        ),
        1,
      );
      expect(count('final a = m.Switch();', 'c.adaptive', imports: pre), 1);
      expect(
        count('final a = const m.AlertDialog();', 'b.dialog', imports: pre),
        1,
      );
      expect(
        count(
          'void f() { m.showDialog(context: c); }',
          'b.dialog',
          imports: pre,
        ),
        1,
      );
    });

    test('prefixed Colors count once, transparent does not', () {
      expect(count('final a = m.Colors.red;', 'a.color', imports: pre), 1);
      expect(
        count('final a = m.Colors.red.shade50;', 'a.color', imports: pre),
        1,
      );
      expect(
        count('final a = m.Colors.transparent;', 'a.color', imports: pre),
        0,
      );
      expect(count('final a = Colors.red.shade50;', 'a.color'), 1);
    });

    test('on-scale and non-prefix targets stay uncounted', () {
      expect(
        count('final a = m.EdgeInsets.all(8);', 'a.spacing', imports: pre),
        0,
      );
      expect(
        count('final a = other.EdgeInsets.all(7);', 'a.spacing', imports: pre),
        0,
      );
      expect(
        count(
          'final a = [const m.SizedBox.square(dimension: 7, child: x)];',
          'a.spacing',
          imports: pre,
        ),
        0,
      );
    });
  });

  group('b.dialog prefixes', () {
    const prefixed = "import 'package:flutter/material.dart' as material;\n";
    test('counts a call through an import prefix', () {
      expect(
        scan(
          'void f() { material.showDialog(context: c, builder: b); }',
          imports: prefixed,
        ),
        ['b.dialog'],
      );
      expect(scan('final a = material.AlertDialog();', imports: prefixed), [
        'b.dialog',
      ]);
    });

    test('ignores a method on an ordinary object', () {
      expect(
        scan('void f() { helper.showDialog(context: c); }', imports: prefixed),
        isEmpty,
      );
    });
  });

  group('d.string', () {
    test('counts literal text and labels', () {
      expect(scan("final a = Text('Retry');"), ['d.string']);
      expect(scan("final a = const Text('Retry');"), ['d.string']);
      expect(scan("final a = SelectableText('Model: \$m');"), ['d.string']);
      expect(scan("final a = Foo(label: 'Add');"), ['d.string']);
      expect(scan("final a = Foo(tooltip: 'Stop');"), ['d.string']);
      expect(scan("final a = Foo(hintText: 'Search');"), ['d.string']);
      expect(scan("final a = Foo(labelText: 'Name');"), ['d.string']);
      expect(scan("final a = Foo(helperText: 'Optional');"), ['d.string']);
      expect(scan("final a = Foo(semanticLabel: 'Close');"), ['d.string']);
      expect(scan("final a = Foo(title: 'Bots');"), ['d.string']);
      expect(scan("final a = Foo(hint: 'Pick one');"), ['d.string']);
      expect(scan("final a = Foo(semanticsLabel: 'Close');"), ['d.string']);
      expect(scan("final a = Tooltip(message: 'Copy');"), ['d.string']);
      expect(scan("final a = TextSpan(text: 'Live');"), ['d.string']);
      expect(scan("final a = Text(c ? 'Open' : 'Close');"), ['d.string']);
    });

    test('a title that is a Text counts once', () {
      expect(scan("final a = Foo(title: const Text('Bots'));"), ['d.string']);
    });

    test('ignores localised, empty and symbol-only text', () {
      expect(scan('final a = Text(context.l10n.retry);'), isEmpty);
      expect(scan("final a = Text('');"), isEmpty);
      expect(scan("final a = Text('—');"), isEmpty);
      expect(scan("final a = Text('\$count');"), isEmpty);
      expect(scan("final a = Text('\${a.b}');"), isEmpty);
      expect(scan("final a = Text('x');"), isEmpty);
      expect(scan("final a = Text('0 9 * * 1-5');"), isEmpty);
      expect(scan("final a = Foo(message: 'Copy');"), isEmpty);
      expect(scan("final a = Foo(other: 'Copy');"), isEmpty);
    });

    test('only counts files that import the widget layer', () {
      expect(scan("final a = Text('Retry');", imports: ''), isEmpty);
    });
  });

  group('scope', () {
    test('skips the theme, l10n and generated files', () {
      expect(isSkipped('lib/src/theme/hermes_theme.dart'), isTrue);
      expect(isSkipped('lib/l10n/l10n.dart'), isTrue);
      expect(isSkipped('lib/l10n/gen/app_localizations.dart'), isTrue);
      expect(isSkipped('lib/src/x.g.dart'), isTrue);
      expect(isSkipped('lib/src/x.freezed.dart'), isTrue);
      expect(isSkipped('lib/src/chat/chat_screen.dart'), isFalse);
    });

    test('names the area of a path', () {
      expect(areaOf('lib/src/chat/widgets/a.dart'), 'chat');
      expect(areaOf('lib/src/app.dart'), 'lib');
      expect(areaOf('lib/main.dart'), 'lib');
    });

    test('reports line numbers and short snippets', () {
      final f = scanSource(
        "$_imports\n\nfinal a = Colors.red;",
        path: 'lib/x.dart',
      ).single;
      expect(f.line, 4);
      expect(f.snippet, 'Colors.red');
    });
  });

  group('allowlist', () {
    final finding = Finding('lib/src/a.dart', 3, 'd.string', "Text('Hermes')");

    test('silences up to count findings, matched by snippet', () {
      final entries = parseAllowlist('''
allow:
  - path: lib/src/a.dart
    category: d.string
    match: Hermes
    reason: brand name
''');
      final result = applyAllowlist([finding, finding], entries);
      expect(result.allowed, 1);
      expect(result.kept, hasLength(1));
      expect(unusedEntries(entries), isEmpty);
    });

    test('reports an entry that matched nothing', () {
      final entries = parseAllowlist('''
- path: lib/src/b.dart
  category: a.color
  reason: scrim
''');
      applyAllowlist([finding], entries);
      expect(unusedEntries(entries), hasLength(1));
    });

    test('requires a reason and a known category', () {
      expect(
        () => parseAllowlist('- {path: a.dart, category: a.color}'),
        throwsA(isA<AllowlistError>()),
      );
      expect(
        () => parseAllowlist('- {path: a.dart, category: nope, reason: x}'),
        throwsA(isA<AllowlistError>()),
      );
    });
  });

  test('rule ids are stable and per file', () {
    final report = StyleReport([
      const Finding(
        'lib/src/a/x.dart',
        1,
        'a.font',
        'fontSize: 12',
        'font.role',
      ),
      const Finding(
        'lib/src/a/x.dart',
        2,
        'a.font',
        'fontSize: 12.5',
        'font.offRole',
      ),
      const Finding('lib/src/a/x.dart', 3, 'd.string', "Text('Hi')"),
      const Finding('lib/src/a/y.dart', 4, 'd.string', "Text('Yo')"),
      const Finding('lib/src/a/y.dart', 5, 'a.iconSize', 'size: 20'),
    ]);
    expect(report.rules, {
      'style.font.offRole': {'lib/src/a/x.dart': 1},
      'style.font.role': {'lib/src/a/x.dart': 1},
      'style.string': {'lib/src/a/x.dart': 1, 'lib/src/a/y.dart': 1},
    });
    expect(report.informationalRules.keys, ['style.iconSize']);
    expect(
      report.ratchetYaml(),
      contains('style.string:\n  lib/src/a/x.dart: 1'),
    );
    expect(ruleIdOf('a.color', null), 'style.color');
    expect(ruleIdOf('b.dialog', null), 'style.dialog');
    expect(ruleIdOf('c.adaptive', null), 'style.adaptive');
    expect(ruleIdOf('a.elevation', null), 'style.elevation');
  });

  test('the report is sorted and totals the scored categories', () {
    final report = StyleReport([
      const Finding('lib/src/b/x.dart', 2, 'a.font', 'fontSize: 12'),
      const Finding('lib/src/a/x.dart', 9, 'a.color', 'Colors.red'),
      const Finding('lib/src/a/x.dart', 1, 'a.color', 'Colors.blue'),
      const Finding('lib/src/a/x.dart', 5, 'a.duration', 'Duration(...)'),
    ]);
    expect(report.total, 3);
    expect(report.categories['a.color'], 2);
    expect(report.areas.keys, ['a', 'b']);
    expect(report.files.first.key, 'lib/src/a/x.dart');
    expect([for (final f in report.sortedFindings) f.line], [1, 5, 9, 2]);
    final json = report.toJson();
    expect(json['total'], 3);
    expect(json['categories'], isA<Map<String, int>>());
  });
}
