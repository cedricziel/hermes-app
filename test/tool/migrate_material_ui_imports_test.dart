import 'package:flutter_test/flutter_test.dart';

import '../../tool/migrate_material_ui_imports.dart';

const _material = 'package:flutter/material.dart';
const _cupertino = 'package:flutter/cupertino.dart';
const _materialUi = 'package:material_ui/material_ui.dart';
const _cupertinoUi = 'package:cupertino_ui/cupertino_ui.dart';

void main() {
  group('migrate', () {
    test('rewrites both barrels and keeps every clause', () {
      const before =
          "import '$_material' show Scaffold, Theme;\n"
          "import '$_material' as m;\n"
          "import '$_cupertino' hide CupertinoIcons;\n"
          "export '$_material';\n";
      expect(
        migrate(before),
        "import '$_materialUi' show Scaffold, Theme;\n"
        "import '$_materialUi' as m;\n"
        "import '$_cupertinoUi' hide CupertinoIcons;\n"
        "export '$_materialUi';\n",
      );
    });

    test('keeps a multi-line directive and double quotes as written', () {
      const before =
          'import "$_material"\n'
          '    show Scaffold,\n'
          '        Theme;\n';
      expect(
        migrate(before),
        'import "$_materialUi"\n'
        '    show Scaffold,\n'
        '        Theme;\n',
      );
    });

    test('keeps a single import when material_ui is already imported', () {
      const before =
          "import '$_material';\n"
          "import '$_materialUi';\n"
          "import '$_materialUi' as mui;\n"
          "import '$_material' as mui;\n"
          '\n'
          'void f() {}\n';
      expect(
        migrate(before),
        "import '$_materialUi';\n"
        "import '$_materialUi' as mui;\n"
        '\n'
        'void f() {}\n',
      );
    });

    test('leaves strings, comments and other imports alone', () {
      const before =
          "import 'dart:async';\n"
          "const src = \"import '$_material';\\n\";\n"
          "// import '$_material';\n"
          "final s = '''\n"
          "x import '$_cupertino';\n"
          "''';\n";
      expect(migrate(before), before);
    });

    test('is idempotent', () {
      const before =
          "import '$_material';\n"
          "import '$_cupertino' show CupertinoIcons;\n";
      final once = migrate(before);
      expect(migrate(once), once);
    });
  });
}
