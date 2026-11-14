import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/files/secret_names.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/files/widgets/file_details_view.dart';
import 'package:hermes_app/src/files/widgets/file_download_progress.dart';
import 'package:hermes_app/src/files/widgets/file_glyph.dart';
import 'package:hermes_app/src/files/widgets/file_path_bar.dart';
import 'package:hermes_app/src/files/widgets/file_preview_cover.dart';
import 'package:hermes_app/src/files/widgets/file_preview_header.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';
import 'package:hermes_app/src/files/widgets/file_row.dart';
import 'package:hermes_app/src/files/widgets/files_browser_view.dart';
import 'package:hermes_app/src/files/widgets/files_failures.dart';
import 'package:hermes_app/src/files/widgets/files_notes.dart';
import 'package:hermes_app/src/files/widgets/files_page_menu.dart';
import 'package:hermes_app/src/files/widgets/files_questions.dart';
import 'package:hermes_app/src/files/widgets/folder_pick_list.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'files_sample_image.dart';
import 'frame.dart';
import 'host.dart';

// Everything here is invented: a made-up server, folder and files.

const _root = '/srv/demo/field-notes';

ServerPath _path(String text) => ServerPath.tryParse(text)!;

final ServerPath _top = _path(_root);

FileRowModel _row(String name, {bool folder = false, String dir = _root}) =>
    FileRowModel(
      name: name,
      isFolder: folder,
      looksSecret: !folder && SecretNames.looksSecretName(name),
      path: _path('$dir/$name'),
    );

final _folders = [
  _row('data', folder: true),
  _row('reports', folder: true),
  _row('scripts', folder: true),
];

final _files = [
  _row('README.md'),
  _row('analysis.py'),
  _row('api_token.txt'),
  _row('build.log'),
  _row('chart.png'),
  _row('deploy-key.pem'),
  _row('export.zip'),
  _row('invoice-2026.pdf'),
  _row('notes.txt'),
  _row('summary.md'),
];

final _hidden = [_row('.env'), _row('.env.local'), _row('.gitignore')];

final List<FileRowModel> _list = [..._folders, ..._files];

/// The first 2,000 rows of a folder of 5,310, as the page cuts a big one.
final List<FileRowModel> _cappedList = [
  ..._folders,
  for (var i = 0; i < 1997; i++)
    _row('sensor-log-${i.toString().padLeft(4, '0')}.txt'),
];

final List<FileRowModel> _listWithHidden = [..._folders, ..._hidden, ..._files];

final List<FileRowModel> _longNames = [
  _row('quarterly-soil-moisture-survey-results-final-reviewed-2026-v3.pdf'),
  _row('averyveryverylongfilenamewithoutanyspacesorseparators_final_final.csv'),
  _row('Notes from the north district visit, second round.txt'),
  _row('a-very-long-folder-name-that-keeps-going-and-going', folder: true),
  _row('api_token.txt'),
  _row('.env.local'),
];

final List<FileRowModel> _nestedList = [
  _row('2026', folder: true, dir: '$_root/reports'),
  _row('2025', folder: true, dir: '$_root/reports'),
  _row('annual-summary.md', dir: '$_root/reports'),
  _row('overview.pdf', dir: '$_root/reports'),
];

const _markdown = '''# Field notes, week 12

Summary of the **soil moisture** survey. The method is on the [methods page](https://example.org/methods); the numbers are in the [raw table](./data/table.md).

![moisture chart](https://example.org/chart.png)

![](img/map.png)

- Plot A: 14.2 %
- Plot B: 11.8 %
- Plot C: 9.4 %

> Numbers are rounded to one decimal.

```
run: sensors --since monday
```
''';

const _python = '''import statistics


def moisture(readings):
    """Average of the valid readings, in percent."""
    valid = [r for r in readings if r is not None]
    if not valid:
        return 0.0
    return statistics.fmean(valid)


if __name__ == "__main__":
    print(moisture([14.2, 11.8, None, 9.4]))
''';

const _log = '''2026-03-02 09:14:01 sensor-a ok 14.2
2026-03-02 09:14:02 sensor-b ok 11.8
2026-03-02 09:14:03 sensor-c timeout, retrying
2026-03-02 09:14:05 sensor-c ok 9.4
2026-03-02 09:14:06 upload finished, 3 readings
2026-03-02 09:15:01 sensor-a ok 14.1
2026-03-02 09:15:02 sensor-b ok 11.9
''';

const _html = '''<!doctype html>
<html>
  <body>
    <h1>Field notes</h1>
    <script>document.title = "never runs";</script>
    <img src="https://example.org/tracker.png">
  </body>
</html>
''';

const _svg = '''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64">
  <circle cx="32" cy="32" r="28" fill="#2e7d5a"/>
</svg>
''';

final _sampleImage = MemoryImage(base64Decode(kFilesSamplePngBase64));

// A stand-in for the screen's own bar, which the catalog does not build.
Widget _bar(BuildContext context, String title, String subtitle) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
    color: scheme.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: context.hermesColors.subtleText,
          ),
        ),
      ],
    ),
  );
}

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Widget _german(Widget child) => Builder(
  builder: (context) => Localizations.override(
    context: context,
    locale: const Locale('de'),
    child: child,
  ),
);

Widget _reducedMotion(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

Widget _on(TargetPlatform platform, Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: platform),
    child: child,
  ),
);

/// An iPad in portrait: regular width, so the questions are alerts.
Widget _ipad(Widget child) => _on(
  TargetPlatform.iOS,
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: const Size(820, 1180)),
      child: child,
    ),
  ),
);

/// The list page of the Files screen without its controller: a bar, the path
/// bar and the list area.
Widget _folderPage(
  BuildContext context, {
  required FolderViewState state,
  ServerPath? current,
  ServerPath? highest,
  ServerPath? selected,
  bool wide = false,
  String title = 'field-notes',
  String subtitle = 'work',
}) {
  final here = current ?? _top;
  final top = highest ?? _top;
  return Column(
    children: [
      _bar(context, title, subtitle),
      FilePathBar(
        current: here,
        highest: top,
        showUp: wide,
        onUp: _sameFolder(here, top) ? null : () {},
        onOpen: (_) {},
      ),
      Expanded(
        child: FilesBrowserView(
          state: state,
          selected: selected,
          onOpen: (_) {},
          onTryAgain: () {},
          onRefresh: () {},
          onShowHidden: () {},
          onUp: () {},
          onGoBack: () {},
        ),
      ),
    ],
  );
}

bool _sameFolder(ServerPath a, ServerPath b) => a.value == b.value;

Widget _folderCase(
  FolderViewState state, {
  ServerPath? current,
  ServerPath? highest,
  String subtitle = 'work',
}) => Builder(
  builder: (context) => fill(
    _folderPage(
      context,
      state: state,
      current: current,
      highest: highest,
      subtitle: subtitle,
    ),
  ),
);

/// The list beside a preview pane, as iPad and desktop lay it out. In a room
/// too narrow for both, only the list shows.
Widget _split(BuildContext context, Widget preview, {ServerPath? selected}) =>
    LayoutBuilder(
      builder: (context, box) {
        final list = _folderPage(
          context,
          state: FolderViewReady(rows: _list),
          selected: selected,
          wide: true,
        );
        if (box.maxWidth < 700) return list;
        return Row(
          children: [
            SizedBox(width: 340, child: list),
            VerticalDivider(
              width: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: SizedBox.expand(child: preview)),
          ],
        );
      },
    );

WidgetbookUseCase _case(String name, Widget Function(BuildContext) builder) =>
    WidgetbookUseCase(name: name, builder: builder);

Widget _rowSection(
  FileRowModel model, {
  bool selected = false,
  bool autofocus = false,
  FileRowMode mode = FileRowMode.browse,
}) => Builder(
  builder: (context) => frame(
    GroupedSection(
      dividerIndent: GroupedMetrics.of(context).indentAfterLeading,
      children: [
        FileRow(
          model: model,
          onTap: () {},
          selected: selected,
          autofocus: autofocus,
          mode: mode,
        ),
      ],
    ),
    maxWidth: 560,
  ),
);

Widget _rowsSection(List<FileRowModel> rows) => Builder(
  builder: (context) => frame(
    GroupedSection(
      dividerIndent: GroupedMetrics.of(context).indentAfterLeading,
      children: [for (final row in rows) FileRow(model: row, onTap: () {})],
    ),
    maxWidth: 560,
  ),
);

// -- Path bar ---------------------------------------------------------------

Widget _bar0({
  required String current,
  String? highest,
  bool wide = false,
  bool atTop = false,
}) => Builder(
  builder: (context) => fill(
    Column(
      children: [
        FilePathBar(
          current: _path(current),
          highest: _path(highest ?? _root),
          showUp: wide,
          onUp: atTop ? null : () {},
          onOpen: (_) {},
        ),
      ],
    ),
  ),
);

WidgetbookComponent _pathBarComponent() => WidgetbookComponent(
  name: 'FilePathBar',
  useCases: [
    _case('One segment', (_) => _bar0(current: _root)),
    _case('Three segments', (_) => _bar0(current: '$_root/reports/2026')),
    _case(
      'Long segment, elided in the middle',
      (_) => _bar0(
        current:
            '$_root/reports/q3-soil-moisture-survey-results-field-team-north-b',
      ),
    ),
    _case(
      'Long path, start faded',
      (_) => _bar0(
        current:
            '$_root/reports/2026/q3/regional-summaries/north-district/week-12',
        highest: '/srv/demo',
      ),
    ),
    _case(
      'Wide, Up enabled',
      (_) => _bar0(current: '$_root/reports/2026', wide: true),
    ),
    _case(
      'Wide, Up disabled at the highest folder',
      (_) => _bar0(current: _root, wide: true, atTop: true),
    ),
    ...onEachPlatform(
      'Three segments',
      (_) => _bar0(current: '$_root/reports/2026', wide: true),
    ),
    _case(
      'Mac, 28 pt targets',
      (_) => _on(
        TargetPlatform.macOS,
        _bar0(current: '$_root/reports/2026', wide: true),
      ),
    ),
    _case(
      'Largest text (3x), scrolls',
      (_) => _scaled(3, _bar0(current: '$_root/reports/2026')),
    ),
    _case('Text 2x', (_) => _scaled(2, _bar0(current: '$_root/reports/2026'))),
    _case(
      'German',
      (_) => _german(_bar0(current: '$_root/reports/2026', wide: true)),
    ),
    _case(
      'Folder picker, reusing the bar and the rows',
      (context) => fill(
        Column(
          children: [
            _bar(context, 'Choose a folder', 'work'),
            FilePathBar(
              current: _path('$_root/reports'),
              highest: _path('/srv/demo'),
              onOpen: (_) {},
            ),
            Expanded(
              child: FolderPickList(
                rows: _nestedList,
                selected: _nestedList.first.path,
                onTap: (_) {},
              ),
            ),
          ],
        ),
      ),
    ),
    _case(
      'Folder picker, no subfolders',
      (context) => fill(
        Column(
          children: [
            _bar(context, 'Choose a folder', 'work'),
            FilePathBar(
              current: _path('$_root/reports/2026'),
              highest: _path('/srv/demo'),
              onOpen: (_) {},
            ),
            Expanded(
              child: FolderPickList(rows: [_row('summary.md')], onTap: (_) {}),
            ),
          ],
        ),
      ),
    ),
  ],
);

// -- File row ---------------------------------------------------------------

WidgetbookComponent _fileRowComponent() => WidgetbookComponent(
  name: 'FileRow',
  useCases: [
    _case('Folder', (_) => _rowSection(_row('reports', folder: true))),
    _case('Text file', (_) => _rowSection(_row('notes.txt'))),
    _case('Code file', (_) => _rowSection(_row('analysis.py'))),
    _case('Image', (_) => _rowSection(_row('chart.png'))),
    _case('PDF', (_) => _rowSection(_row('invoice-2026.pdf'))),
    _case('Archive', (_) => _rowSection(_row('export.zip'))),
    _case('Other file', (_) => _rowSection(_row('sensor.dat'))),
    _case('All kinds', (_) => _rowsSection(_list)),
    _case('Secret-looking file', (_) => _rowSection(_row('.env'))),
    _case(
      'Two-line name, elided in the middle',
      (_) => _rowSection(
        _row(
          'quarterly-soil-moisture-survey-results-final-reviewed-by-the-north-district-team-and-signed-off-2026-v3-with-appendix-b.pdf',
        ),
      ),
    ),
    _case(
      'Selected (wide)',
      (_) => _rowSection(_row('analysis.py'), selected: true),
    ),
    _case(
      'Focused (Mac)',
      (_) => _on(
        TargetPlatform.macOS,
        _rowSection(_row('analysis.py'), autofocus: true),
      ),
    ),
    _case(
      'Picker row, chosen',
      (_) => _rowSection(
        _row('reports', folder: true),
        selected: true,
        mode: FileRowMode.pick,
      ),
    ),
    ...onEachPlatform('All kinds', (_) => _rowsSection(_list)),
    _case(
      'Mac, 32 pt rows',
      (_) => _on(TargetPlatform.macOS, _rowsSection(_list)),
    ),
    _case('German', (_) => _german(_rowsSection(_list))),
    _case('Text 2x', (_) => _scaled(2, _rowsSection(_longNames))),
    _case(
      'Largest text (3x), lock moves under the name',
      (_) => _scaled(3, _rowsSection(_longNames)),
    ),
  ],
);

// -- Browser view -----------------------------------------------------------

WidgetbookComponent _browserComponent() => WidgetbookComponent(
  name: 'FilesBrowserView',
  useCases: [
    ...onEachPlatform(
      'Folder',
      (_) => _folderCase(FolderViewReady(rows: _list)),
    ),
    _case(
      'Nested folder',
      (_) => _folderCase(
        FolderViewReady(rows: _nestedList),
        current: _path('$_root/reports'),
        subtitle: 'work',
      ),
    ),
    _case('Loading', (_) => _folderCase(const FolderViewLoading())),
    ...onEachPlatform('Loading', (_) => _folderCase(const FolderViewLoading())),
    _case(
      'Empty',
      (_) => _folderCase(const FolderViewReady(), subtitle: 'work'),
    ),
    _case(
      'Empty with hidden files',
      (_) => _folderCase(
        const FolderViewReady(hasHiddenFiles: true),
        subtitle: 'work',
      ),
    ),
    _case(
      'Hidden files shown',
      (_) =>
          _folderCase(FolderViewReady(rows: _listWithHidden), subtitle: 'work'),
    ),
    _case(
      'Long names',
      (_) => _folderCase(FolderViewReady(rows: _longNames), subtitle: 'work'),
    ),
    _case(
      'The 2,000 cap',
      (_) => _folderCase(
        FolderViewReady(rows: _cappedList, totalCount: 5310),
        subtitle: 'work',
      ),
    ),
    _case(
      "The server's folder",
      (_) => _folderCase(
        FolderViewReady(rows: _list, showServerFolderNote: true),
        subtitle: 'work',
      ),
    ),
    _case(
      'Unreachable',
      (_) => _folderCase(
        const FolderViewProblem(FolderProblem.unreachable),
        subtitle: 'work',
      ),
    ),
    _case(
      'Offline after a listing',
      (_) => _folderCase(FolderViewReady(rows: _list, stale: true)),
    ),
    _case(
      'Gone (Up)',
      (_) => _folderCase(
        const FolderViewProblem(FolderProblem.gone),
        current: _path('$_root/reports'),
        subtitle: 'work',
      ),
    ),
    _case(
      'Gone at the highest folder (Try again)',
      (_) => _folderCase(
        const FolderViewProblem(FolderProblem.gone, atHighest: true),
        subtitle: 'work',
      ),
    ),
    _case(
      'No permission',
      (_) => _folderCase(
        const FolderViewProblem(FolderProblem.noPermission),
        current: _path('$_root/reports'),
        subtitle: 'work',
      ),
    ),
    _case(
      'Fixed-folder server',
      (_) => _folderCase(
        const FolderViewProblem(FolderProblem.fixedFolder, atHighest: true),
        subtitle: 'work',
      ),
    ),
    _case(
      'Workspace down',
      (_) => _folderCase(
        const FolderViewProblem(FolderProblem.workspaceDown),
        subtitle: 'work',
      ),
    ),
    _case(
      'Link outside the folder',
      (_) => _folderCase(
        const FolderViewProblem(FolderProblem.outside),
        subtitle: 'work',
      ),
    ),
    _case(
      'Folder or profile not accepted',
      (_) => _folderCase(
        const FolderViewProblem(FolderProblem.notAccepted),
        subtitle: 'work',
      ),
    ),
    _case(
      'Page menu',
      (context) => fill(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _bar(context, 'field-notes', 'work')),
                FilesPageMenuButton(
                  path: _top,
                  showHidden: true,
                  onSelected: (_) {},
                ),
              ],
            ),
            Expanded(
              child: FilesBrowserView(
                state: FolderViewReady(rows: _list),
                onOpen: (_) {},
              ),
            ),
          ],
        ),
      ),
    ),
    _case(
      'About this list',
      (_) => openOnShow(
        (context) => showFilesAboutList(context),
        behind: _folderCase(FolderViewReady(rows: _list)),
      ),
    ),
    _case(
      'Wide, nothing selected',
      (context) => fill(_split(context, const FilesNoSelection())),
    ),
    _case(
      'Wide, a file selected',
      (context) => fill(
        _split(
          context,
          FilePreviewView(content: const TextContent(_python)),
          selected: _list[4].path,
        ),
      ),
    ),
    _case('German', (_) => _german(_folderCase(FolderViewReady(rows: _list)))),
    _case(
      'German, empty',
      (_) => _german(_folderCase(const FolderViewReady(hasHiddenFiles: true))),
    ),
    _case(
      'Text 2x',
      (_) => _scaled(2, _folderCase(FolderViewReady(rows: _list))),
    ),
    _case(
      'Largest text (3x)',
      (_) => _scaled(3, _folderCase(FolderViewReady(rows: _list))),
    ),
    _case(
      'Largest text (3x), failure',
      (_) => _scaled(
        3,
        _folderCase(const FolderViewProblem(FolderProblem.notAccepted)),
      ),
    ),
  ],
);

// -- Notes ------------------------------------------------------------------

WidgetbookComponent _notesComponent() => WidgetbookComponent(
  name: 'Notes (shared banner)',
  useCases: [
    _case(
      'Working folder of the server',
      (_) => frame(const FilesServerFolderNote()),
    ),
    _case(
      'Showing the first 512 KB',
      (_) => frame(
        FilesTruncatedNote(
          shownBytes: 512 * 1024,
          totalBytes: 3355443,
          onDownloadFull: () {},
        ),
      ),
    ),
    _case(
      'Offline, list may be out of date',
      (_) => frame(FilesOfflineBanner(onRetry: () {})),
    ),
    _case(
      'German',
      (_) => _german(
        frame(
          Column(
            children: [
              const FilesServerFolderNote(),
              const SizedBox(height: 12),
              FilesTruncatedNote(
                shownBytes: 512 * 1024,
                totalBytes: 3355443,
                onDownloadFull: () {},
              ),
              const SizedBox(height: 12),
              FilesOfflineBanner(onRetry: () {}),
            ],
          ),
        ),
      ),
    ),
    _case(
      'Largest text (3x)',
      (_) => _scaled(
        3,
        frame(
          FilesTruncatedNote(
            shownBytes: 512 * 1024,
            totalBytes: 3355443,
            onDownloadFull: () {},
          ),
        ),
      ),
    ),
  ],
);

// -- Preview header ---------------------------------------------------------

Widget _header({
  String name = 'analysis.py',
  int? size = 1834,
  Widget Function(BuildContext, Widget)? wrapTile,
}) => frame(
  FilePreviewHeader(
    name: name,
    size: size,
    onShare: () {},
    onSave: () {},
    onQuickLook: () {},
    onOpenWith: () {},
    onReload: () {},
    wrapTile: wrapTile,
  ),
  maxWidth: 640,
);

const _longName =
    'quarterly-soil-moisture-survey-results-final-reviewed-2026-v3.pdf';

WidgetbookComponent _previewHeaderComponent() => WidgetbookComponent(
  name: 'FilePreviewHeader',
  useCases: [
    _case('iPad, one-line name', (_) => _ipad(_header())),
    _case('iPad, two-line name', (_) => _ipad(_header(name: _longName))),
    _case('iPad, size not known yet', (_) => _ipad(_header(size: null))),
    _case(
      'Mac, Quick Look, Save and More',
      (_) =>
          _on(TargetPlatform.macOS, _header(wrapTile: (context, tile) => tile)),
    ),
    _case(
      'Mac, two-line name',
      (_) => _on(TargetPlatform.macOS, _header(name: _longName)),
    ),
    _case(
      'Material',
      (_) => _on(TargetPlatform.android, _header(name: _longName)),
    ),
    _case('German', (_) => _german(_ipad(_header()))),
    _case(
      'Largest text (3x)',
      (_) => _scaled(3, _ipad(_header(name: _longName))),
    ),
  ],
);

// -- Preview views ----------------------------------------------------------

Widget _view(FilePreviewContent content) => Builder(
  builder: (context) => fill(
    FilePreviewView(
      content: content,
      onDownloadFull: () {},
      confirmLink: (context, host) async => true,
      openLink: (uri) async => true,
    ),
  ),
);

Widget _markdownWithControl({required bool source}) => Builder(
  builder: (context) => StatefulBuilder(
    builder: (context, setState) {
      return fill(
        Column(
          children: [
            MarkdownModeControl(
              showSource: source,
              onChanged: (value) => setState(() => source = value),
            ),
            Expanded(
              child: FilePreviewView(
                content: MarkdownContent(_markdown, showSource: source),
                confirmLink: (context, host) async => true,
                openLink: (uri) async => true,
              ),
            ),
          ],
        ),
      );
    },
  ),
);

WidgetbookComponent _previewViewComponent() => WidgetbookComponent(
  name: 'FilePreviewView',
  useCases: [
    _case('Text', (_) => _view(const TextContent(_log))),
    _case('Code', (_) => _view(const CodeContent(_python))),
    _case('Markdown, rendered', (_) => _view(const MarkdownContent(_markdown))),
    _case(
      'Markdown, source',
      (_) => _view(const MarkdownContent(_markdown, showSource: true)),
    ),
    _case(
      'Markdown with the Rendered and Source switch',
      (_) => _markdownWithControl(source: false),
    ),
    _case(
      'Markdown with a remote image, a link and a relative link',
      (_) => _view(
        const MarkdownContent(
          'Chart: ![moisture chart](https://example.org/chart.png)\n\n'
          'No alt text: ![](https://example.org/map.png)\n\n'
          'A link to [example.org](https://example.org/methods) asks first.\n\n'
          'A relative link to [the table](./data/table.md) does nothing.\n\n'
          'A relative image ![sketch](img/sketch.png) shows its alt text.',
        ),
      ),
    ),
    _case('HTML, as source', (_) => _view(const CodeContent(_html))),
    _case('SVG, as source', (_) => _view(const CodeContent(_svg))),
    _case(
      'Image, with a transparent area',
      (_) => _view(ImageContent(_sampleImage, label: 'chart.png')),
    ),
    _case(
      'Truncated text, with its note',
      (_) => _view(
        const TextContent(
          _log,
          truncation: FileTruncation(
            shownBytes: 512 * 1024,
            totalBytes: 3355443,
          ),
        ),
      ),
    ),
    _case(
      'Truncated, German',
      (_) => _german(
        _view(
          const TextContent(
            _log,
            truncation: FileTruncation(
              shownBytes: 512 * 1024,
              totalBytes: 3355443,
            ),
          ),
        ),
      ),
    ),
    _case(
      'Mac text',
      (_) => _on(TargetPlatform.macOS, _view(const TextContent(_python))),
    ),
    _case(
      'Largest text (3x), code',
      (_) => _scaled(3, _view(const CodeContent(_python))),
    ),
    _case(
      'Largest text (3x), truncated',
      (_) => _scaled(
        3,
        _view(
          const TextContent(
            _log,
            truncation: FileTruncation(
              shownBytes: 512 * 1024,
              totalBytes: 3355443,
            ),
          ),
        ),
      ),
    ),
  ],
);

// -- Details view -----------------------------------------------------------

enum _Act { open, save, share, openWith }

Widget _details({
  required String name,
  int? size,
  bool tooLarge = false,
  required _Act primary,
  List<_Act> secondary = const [],
}) => Builder(
  builder: (context) {
    final l10n = context.l10n;
    String label(_Act act) => switch (act) {
      _Act.open => l10n.filesActionOpen,
      _Act.save => l10n.filesActionSave,
      _Act.share => l10n.filesActionShare,
      _Act.openWith => l10n.filesActionOpenWith,
    };
    return fill(
      FileDetailsView(
        name: name,
        size: size,
        note: tooLarge ? l10n.filesDetailsTooLarge : null,
        primary: FileDetailsAction(label: label(primary), onPressed: () {}),
        secondary: [
          for (final act in secondary)
            FileDetailsAction(label: label(act), onPressed: () {}),
        ],
      ),
    );
  },
);

WidgetbookComponent _detailsComponent() => WidgetbookComponent(
  name: 'FileDetailsView',
  useCases: [
    _case(
      'PDF, Open',
      (_) => _details(
        name: 'invoice-2026.pdf',
        size: 2516582,
        primary: _Act.open,
        secondary: [_Act.save, _Act.share],
      ),
    ),
    _case(
      'Other file, iPhone (Save and Share)',
      (_) => _details(
        name: 'export.zip',
        primary: _Act.save,
        secondary: [_Act.share],
      ),
    ),
    _case(
      'Other file, Android and desktop (Save and Open with…)',
      (_) => _on(
        TargetPlatform.android,
        _details(
          name: 'export.zip',
          primary: _Act.save,
          secondary: [_Act.openWith],
        ),
      ),
    ),
    _case(
      'Other file, Mac',
      (_) => _on(
        TargetPlatform.macOS,
        _details(
          name: 'export.zip',
          primary: _Act.save,
          secondary: [_Act.openWith],
        ),
      ),
    ),
    _case(
      'Too large to open here',
      (_) => _details(
        name: 'sensor-dump-2026-03.db',
        size: 222298112,
        tooLarge: true,
        primary: _Act.save,
        secondary: [_Act.share],
      ),
    ),
    _case(
      'Saved, with the snack bar',
      (_) => openOnShow(
        (context) async => showFilesSaved(context, 'export.zip'),
        behind: _details(
          name: 'export.zip',
          size: 4404019,
          primary: _Act.save,
          secondary: [_Act.share],
        ),
      ),
    ),
    _case(
      'Cancelled (as an other file)',
      (_) => _details(
        name: 'export.zip',
        size: 4404019,
        primary: _Act.save,
        secondary: [_Act.share],
      ),
    ),
    _case(
      'German',
      (_) => _german(
        _details(
          name: 'export.zip',
          size: 4404019,
          tooLarge: true,
          primary: _Act.save,
          secondary: [_Act.share],
        ),
      ),
    ),
    _case(
      'Largest text (3x)',
      (_) => _scaled(
        3,
        _details(
          name: _longName,
          size: 4404019,
          tooLarge: true,
          primary: _Act.save,
          secondary: [_Act.share],
        ),
      ),
    ),
  ],
);

// -- App switcher cover -----------------------------------------------------

WidgetbookComponent _coverComponent() => WidgetbookComponent(
  name: 'FilePreviewCover',
  useCases: [
    for (final (label, glyph) in [
      ('Text', FileGlyph.text),
      ('Code', FileGlyph.code),
      ('Image', FileGlyph.image),
      ('PDF', FileGlyph.pdf),
      ('Archive', FileGlyph.archive),
      ('Other file', FileGlyph.generic),
    ])
      _case(label, (_) => fill(FilePreviewCover(glyph: glyph))),
    _case(
      'Covering a preview',
      (_) => fill(
        Stack(
          fit: StackFit.expand,
          children: [
            const FilePreviewView(content: CodeContent(_python)),
            const FilePreviewCover(glyph: FileGlyph.code),
          ],
        ),
      ),
    ),
  ],
);

// -- Download progress ------------------------------------------------------

WidgetbookComponent _progressComponent() => WidgetbookComponent(
  name: 'FileDownloadProgress',
  useCases: [
    _case(
      'With a length',
      (_) => fill(
        FileDownloadProgress(
          received: 14680064,
          total: 31457280,
          onCancel: () {},
        ),
      ),
    ),
    _case(
      'Without a length',
      (_) => fill(FileDownloadProgress(received: 12582912, onCancel: () {})),
    ),
    _case(
      'Reduced motion, with a length',
      (_) => _reducedMotion(
        fill(
          FileDownloadProgress(
            received: 14680064,
            total: 31457280,
            onCancel: () {},
          ),
        ),
      ),
    ),
    _case(
      'Reduced motion, without a length (still spinner)',
      (_) => _reducedMotion(
        fill(FileDownloadProgress(received: 12582912, onCancel: () {})),
      ),
    ),
    _case(
      'German',
      (_) => _german(
        fill(
          FileDownloadProgress(
            received: 14680064,
            total: 31457280,
            onCancel: () {},
          ),
        ),
      ),
    ),
    _case(
      'Largest text (3x)',
      (_) => _scaled(
        3,
        fill(
          FileDownloadProgress(
            received: 14680064,
            total: 31457280,
            onCancel: () {},
          ),
        ),
      ),
    ),
  ],
);

// -- File failures ----------------------------------------------------------

WidgetbookComponent _failuresComponent() => WidgetbookComponent(
  name: 'File failures',
  useCases: [
    for (final (label, problem) in [
      ('Not shared (403)', FileProblem.notShared),
      ('Gone (404)', FileProblem.gone),
      ('In use by a database (409)', FileProblem.busy),
      ('Not a file (400)', FileProblem.notAFile),
      ("Couldn't open", FileProblem.couldntOpen),
      ('Incomplete download', FileProblem.incomplete),
    ])
      _case(
        label,
        (_) => fill(FilePreviewFailure(problem: problem, onTryAgain: () {})),
      ),
    _case(
      'German',
      (_) => _german(
        fill(
          FilePreviewFailure(
            problem: FileProblem.incomplete,
            onTryAgain: () {},
          ),
        ),
      ),
    ),
    _case(
      'Largest text (3x)',
      (_) => _scaled(
        3,
        fill(FilePreviewFailure(problem: FileProblem.busy, onTryAgain: () {})),
      ),
    ),
  ],
);

// -- Questions --------------------------------------------------------------

Widget _askBehind() => _details(
  name: 'sensor-dump-2026-03.db',
  size: null,
  primary: _Act.save,
  secondary: [_Act.share],
);

WidgetbookUseCase _ask(
  String name,
  Future<void> Function(BuildContext context) open, {
  Widget Function(Widget)? wrap,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) {
    final page = openOnShow(open, behind: _askBehind());
    // Under an iOS theme unless a wrap says otherwise, so the Apple dialogs show.
    return _on(TargetPlatform.iOS, wrap == null ? page : wrap(page));
  },
);

Widget _sheetAlone() => Builder(
  builder: (context) => fill(
    Align(
      alignment: Alignment.bottomCenter,
      child: FileSizeSheet(
        sentence: context.l10n.filesSizeQuestion('212 MB'),
        onCancel: () {},
        onDownload: () {},
      ),
    ),
  ),
);

WidgetbookComponent _questionsComponent() => WidgetbookComponent(
  name: 'Questions',
  useCases: [
    _ask('Size, phone sheet', (context) async {
      await askDownloadLargeFile(context, 222298112);
    }),
    _ask('Size, iPad alert', (context) async {
      await askDownloadLargeFile(context, 222298112);
    }, wrap: _ipad),
    _ask('Size, Mac alert', (context) async {
      await askDownloadLargeFile(context, 222298112);
    }, wrap: (child) => _on(TargetPlatform.macOS, child)),
    _ask('Size, Android', (context) async {
      await askDownloadLargeFile(context, 222298112);
    }, wrap: (child) => _on(TargetPlatform.android, child)),
    _ask('Size, German', (context) async {
      await askDownloadLargeFile(context, 222298112);
    }, wrap: _german),
    _ask('Secret, iPhone', (context) async {
      await askOpenSecretFile(context, '.env');
    }),
    _ask('Secret, Mac', (context) async {
      await askOpenSecretFile(context, '.env');
    }, wrap: (child) => _on(TargetPlatform.macOS, child)),
    _ask('Secret, Android (two text buttons)', (context) async {
      await askOpenSecretFile(context, '.env');
    }, wrap: (child) => _on(TargetPlatform.android, child)),
    _ask('Secret, German', (context) async {
      await askOpenSecretFile(context, 'api_token.txt');
    }, wrap: _german),
    _ask('Open a link', (context) async {
      await confirmOpenLink(context, 'example.org');
    }),
    WidgetbookUseCase(name: 'Size sheet, alone', builder: (_) => _sheetAlone()),
    WidgetbookUseCase(
      name: 'Size sheet, largest text (3x)',
      builder: (_) => _scaled(3, _sheetAlone()),
    ),
  ],
);

// -- Accessibility ----------------------------------------------------------

WidgetbookComponent _accessibilityComponent() => WidgetbookComponent(
  name: 'Accessibility',
  useCases: [
    _case(
      'Names wrap at the largest text (3x)',
      (_) => _scaled(
        3,
        _rowsSection([
          _row('.env.local'),
          _row('api_token.txt'),
          _row('Notes from the north district visit.txt'),
        ]),
      ),
    ),
    _case(
      'Names at text 2x',
      (_) => _scaled(
        2,
        _rowsSection([
          _row('.env.local'),
          _row('api_token.txt'),
          _row('Notes from the north district visit.txt'),
        ]),
      ),
    ),
    _case(
      'Scaled buttons (details, 3x)',
      (_) => _scaled(
        3,
        _details(
          name: 'export.zip',
          size: 4404019,
          primary: _Act.save,
          secondary: [_Act.share],
        ),
      ),
    ),
    _case(
      'Path bar segments are focusable buttons',
      (context) => fill(
        Column(
          children: [
            _FocusFirst(
              child: FilePathBar(
                current: _path('$_root/reports/2026'),
                highest: _top,
                showUp: true,
                onUp: () {},
                onOpen: (_) {},
              ),
            ),
          ],
        ),
      ),
    ),
    _case(
      'Reduced motion: loading',
      (_) => _reducedMotion(_folderCase(const FolderViewLoading())),
    ),
    _case(
      'Reduced motion: download without a length',
      (_) => _reducedMotion(
        fill(FileDownloadProgress(received: 12582912, onCancel: () {})),
      ),
    ),
    _case(
      'Mac rows at 32 pt, other targets at 28 pt',
      (context) => _on(
        TargetPlatform.macOS,
        fill(
          Builder(
            builder: (context) => _split(
              context,
              Column(
                children: [
                  FilePreviewHeader(
                    name: 'analysis.py',
                    size: 1834,
                    onQuickLook: () {},
                    onSave: () {},
                  ),
                  const Expanded(
                    child: FilePreviewView(content: CodeContent(_python)),
                  ),
                ],
              ),
              selected: _list[4].path,
            ),
          ),
        ),
      ),
    ),
  ],
);

/// Puts keyboard focus on the first button below it, as Tab would.
class _FocusFirst extends StatefulWidget {
  const _FocusFirst({required this.child});

  final Widget child;

  @override
  State<_FocusFirst> createState() => _FocusFirstState();
}

class _FocusFirstState extends State<_FocusFirst> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      FocusScope.of(context).nextFocus();
      FocusScope.of(context).nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

WidgetbookNode filesNode() => WidgetbookFolder(
  name: 'Files',
  children: [
    _pathBarComponent(),
    _fileRowComponent(),
    _browserComponent(),
    _notesComponent(),
    _previewHeaderComponent(),
    _previewViewComponent(),
    _detailsComponent(),
    _coverComponent(),
    _progressComponent(),
    _failuresComponent(),
    _questionsComponent(),
    _accessibilityComponent(),
  ],
);
