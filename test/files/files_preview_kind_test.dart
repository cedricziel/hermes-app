import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/files_preview_kind.dart';

void main() {
  test('names decide the kind, in any letter case', () {
    expect(previewKindFor('app.py'), FilePreviewKind.code);
    expect(previewKindFor('APP.PY'), FilePreviewKind.code);
    expect(previewKindFor('report.md'), FilePreviewKind.markdown);
    expect(previewKindFor('notes.txt'), FilePreviewKind.text);
    expect(previewKindFor('Dockerfile'), FilePreviewKind.text);
    expect(previewKindFor('.gitignore'), FilePreviewKind.text);
    expect(previewKindFor('chart.PNG'), FilePreviewKind.image);
    expect(previewKindFor('a.pdf'), FilePreviewKind.pdf);
    expect(previewKindFor('export.zip'), FilePreviewKind.other);
    expect(previewKindFor('noextension'), FilePreviewKind.other);
    expect(previewKindFor('trailing.'), FilePreviewKind.other);
  });

  test('HTML and SVG are source text, never rendered', () {
    expect(previewKindFor('page.html'), FilePreviewKind.code);
    expect(previewKindFor('logo.svg'), FilePreviewKind.code);
    expect(FilePreviewKind.code.readsText, isTrue);
    expect(FilePreviewKind.image.readsText, isFalse);
  });
}
