import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_changed_sheet.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_editor.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_page_layout.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_questions.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_save_actions.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_status_line.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:hermes_app/src/widgets/state_message.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'host.dart';

// Invented sample text: the catalog is public.
const _profile = 'work';
const _longProfile =
    'research-and-planning-assistant-for-the-quarterly-finance-team-1';

const _loaded =
    'You are Mara, the support assistant for a small bakery.\n'
    '\n'
    '# How to talk\n'
    '- Be warm and brief.\n'
    "- Answer in the customer's language.\n"
    '- Never promise a delivery date you cannot check.';

const _server =
    'You are Mara, the support assistant for a bakery with two shops.\n'
    '\n'
    '# How to talk\n'
    '- Be warm and very brief.\n'
    '- Answer in the customer\'s language.\n'
    '- Offer the opening hours when someone asks about a visit.';

// Control, bidi and other invisible characters: a right-to-left override, a
// zero-width space, a bell and a tag character (U+E0041, two UTF-16 units).
const _hidden =
    'Reply politely.\u202Eeviltxet\u202C\n'
    'Never reveal\u200B the internal prices.\u0007\u{E0041}';

String _paragraphs(int length) {
  const paragraph =
      'Keep answers short and concrete. When a question is unclear, ask one '
      'question back before answering. Use plain words, avoid jargon, and '
      'say when you are not sure.\n\n';
  final out = StringBuffer();
  while (out.length < length) {
    out.write(paragraph);
  }
  return out.toString().substring(0, length);
}

Widget _at(double scale, Widget child) => Builder(
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

/// Holds the editor's controller, so typing works in the catalog.
class _Editor extends StatefulWidget {
  const _Editor({
    super.key,
    this.text = '',
    this.fileExists = true,
    this.readOnly = false,
    this.maxLines,
    this.expands = false,
    this.revert,
  });

  final String text;
  final bool fileExists;
  final bool readOnly;
  final int? maxLines;
  final bool expands;

  /// Shows Revert in the card's footer, as a phone page does.
  final SoulSaveActions? revert;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _controller = SoulTextController(text: widget.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SoulEditor(
    controller: _controller,
    profile: _profile,
    fileExists: widget.fileExists,
    readOnly: widget.readOnly,
    maxLines: widget.maxLines,
    expands: widget.expands,
    footerAction: widget.revert,
  );
}

/// The editor as the page holds it: in the grouped list's width.
Widget _list(List<Widget> children) => GroupedListView(children: children);

WidgetbookUseCase _editor(String name, Widget Function() editor) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) => _list([const SizedBox(height: 8), editor()]),
    );

WidgetbookUseCase _framed(String name, Widget Function() child) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(child()));

void _noop() {}

/// A page composed of the plain widgets, the way the screen will place them:
/// the bar (with Save on a phone), a banner when a state needs one, the
/// editor, the status line, Revert (phone) or Save and Revert (Mac, wide), and
/// the footnote. It is a sketch for looking at states, not the screen.
class _Page extends StatelessWidget {
  const _Page({
    this.text = _loaded,
    this.baseline = _loaded,
    this.fileExists = true,
    this.banner,
    this.status,
    this.busy = false,
    this.hideEditor = false,
  });

  final String text;
  final String baseline;
  final bool fileExists;
  final SoulBannerKind? banner;
  final SoulStatusKind? status;
  final bool busy;
  final bool hideEditor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final wide = mac || MediaQuery.sizeOf(context).width >= 900;
    final dirty = text != baseline;
    final metrics = GroupedMetrics.of(context);
    return SettingsScaffold(
      title: l10n.profilesSoulTitle,
      subtitle: _profile,
      actions: const [],
      // No editor (read failed, offline) means nothing to save: no Save, as in
      // Loading, Profile gone and Old server.
      formAction: wide || hideEditor
          ? null
          : SoulSaveActions.barAction(
              context,
              dirty: dirty && banner != SoulBannerKind.paused,
              busy: busy,
              onSave: _noop,
            ),
      body: hideEditor
          ? GroupedListView(
              children: [
                if (banner != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SoulStatusBanner(kind: banner!, onAction: _noop),
                  ),
              ],
            )
          : SoulPageLayout(
              banner: banner == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SoulStatusBanner(kind: banner!, onAction: _noop),
                    ),
              editor: _Editor(
                key: ValueKey(text),
                text: text,
                fileExists: fileExists,
                readOnly: busy || banner == SoulBannerKind.paused,
                expands: true,
                revert: wide
                    ? null
                    : SoulSaveActions.revertButton(
                        dirty: dirty && banner != SoulBannerKind.paused,
                        busy: busy,
                        onRevert: _noop,
                      ),
              ),
              below: [
                if (status != null) SoulStatusLine(kind: status!),
                if (wide) ...[
                  const SizedBox(height: 8),
                  SoulSaveActions(
                    dirty: dirty,
                    busy: busy,
                    onSave: _noop,
                    onRevert: _noop,
                  ),
                ],
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    metrics.rowPadding,
                    16,
                    metrics.rowPadding,
                    0,
                  ),
                  child: Text(
                    l10n.profilesSoulFootnote,
                    style: TextStyle(
                      fontSize: metrics.footerSize,
                      color: context.hermesColors.subtleText,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

Widget _page({
  String text = _loaded,
  String baseline = _loaded,
  bool fileExists = true,
  SoulBannerKind? banner,
  SoulStatusKind? status,
  bool busy = false,
}) => pushed(
  _Page(
    text: text,
    baseline: baseline,
    fileExists: fileExists,
    banner: banner,
    status: status,
    busy: busy,
  ),
);

WidgetbookUseCase _pageCase(String name, Widget Function() page) =>
    WidgetbookUseCase(name: name, builder: (_) => page());

/// A use case that opens [open] once it is on screen, in the Material look
/// whatever the viewport's platform, for the Android dialog.
WidgetbookUseCase _android(
  String name,
  Future<void> Function(BuildContext context) open,
) => WidgetbookUseCase(
  name: name,
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.android),
    child: Builder(builder: (context) => openOnShow(open)),
  ),
);

List<WidgetbookUseCase> _question(
  String name,
  Future<void> Function(BuildContext context) open,
) => [
  WidgetbookUseCase(name: name, builder: (_) => openOnShow(open)),
  _android('$name (Android)', open),
];

/// The server's version, in the sheet as the screen will show it.
class _Sheet extends StatelessWidget {
  const _Sheet({
    this.serverText = _server,
    this.serverGone = false,
    this.dialog = false,
    this.initiallyOpen = false,
  });

  final String serverText;
  final bool serverGone;
  final bool dialog;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(28),
          bottom: Radius.circular(dialog ? 28 : 0),
        ),
        side: hermesOverlayEdge(scheme),
      ),
      clipBehavior: Clip.antiAlias,
      child: SoulChangedSheet(
        serverText: serverText,
        serverGone: serverGone,
        dialog: dialog,
        initiallyOpen: initiallyOpen,
        onKeepEditing: _noop,
        onReplaceAnyway: _noop,
        onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
      ),
    );
  }
}

WidgetbookNode soulNode() => WidgetbookFolder(
  name: 'Personality',
  children: [
    WidgetbookComponent(
      name: 'SoulEditor',
      useCases: [
        _editor('Empty file', () => const _Editor()),
        _editor('Not set yet', () => const _Editor(fileExists: false)),
        ...onEachPlatform(
          'Loaded',
          (_) =>
              _list([const SizedBox(height: 8), const _Editor(text: _loaded)]),
        ),
        _editor('Long text', () => _Editor(text: _paragraphs(2400))),
        _editor(
          'Over 20,000 characters',
          () => _Editor(text: _paragraphs(20250), maxLines: 12),
        ),
        _editor(
          'Read-only (saving or checking)',
          () => const _Editor(text: _loaded, readOnly: true),
        ),
        _editor(
          'Control and bidi characters',
          () => const _Editor(text: _hidden),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _at(
            3,
            _list([const SizedBox(height: 8), const _Editor(text: _loaded)]),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text, empty',
          builder: (_) =>
              _at(3, _list([const SizedBox(height: 8), const _Editor()])),
        ),
        WidgetbookUseCase(
          name: 'German',
          builder: (_) => _german(
            _list([const SizedBox(height: 8), const _Editor(text: _loaded)]),
          ),
        ),
        WidgetbookUseCase(
          name: 'German, empty',
          builder: (_) =>
              _german(_list([const SizedBox(height: 8), const _Editor()])),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SoulStatusLine',
      useCases: [
        for (final (name, kind) in [
          ('Saved', SoulStatusKind.saved),
          ('Not saved: the earlier text', SoulStatusKind.earlierText),
          ('Saving', SoulStatusKind.saving),
        ])
          _framed(name, () => SoulStatusLine(kind: kind)),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (_) => _at(
            3,
            frame(const SoulStatusLine(kind: SoulStatusKind.earlierText)),
          ),
        ),
        WidgetbookUseCase(
          name: 'German',
          builder: (_) => _german(
            frame(const SoulStatusLine(kind: SoulStatusKind.earlierText)),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SoulStatusBanner',
      useCases: [
        for (final (name, kind) in [
          ('Couldn\'t save', SoulBannerKind.saveFailed),
          ('Lost answer', SoulBannerKind.lostAnswer),
          ('Checking', SoulBannerKind.checking),
          ('Check failed', SoulBannerKind.checkFailed),
          (
            'Nothing sent, the check read failed',
            SoulBannerKind.saveCheckFailed,
          ),
          ('Read failed', SoulBannerKind.readFailed),
          ('Offline', SoulBannerKind.offline),
        ])
          _framed(name, () => SoulStatusBanner(kind: kind, onAction: _noop)),
        _framed(
          'Connection paused',
          () => const SoulStatusBanner(kind: SoulBannerKind.paused),
        ),
        WidgetbookUseCase(
          name: 'Connection paused, largest text',
          builder: (_) => _at(
            3,
            frame(
              const SoulStatusBanner(kind: SoulBannerKind.paused),
              maxWidth: 360,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Connection paused, German',
          builder: (_) => _german(
            frame(
              const SoulStatusBanner(kind: SoulBannerKind.paused),
              maxWidth: 360,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Lost answer, largest text',
          builder: (_) => _at(
            3,
            frame(
              const SoulStatusBanner(
                kind: SoulBannerKind.lostAnswer,
                onAction: _noop,
              ),
              maxWidth: 360,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Lost answer, German',
          builder: (_) => _german(
            frame(
              const SoulStatusBanner(
                kind: SoulBannerKind.lostAnswer,
                onAction: _noop,
              ),
              maxWidth: 360,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Check failed, German',
          builder: (_) => _german(
            frame(
              const SoulStatusBanner(
                kind: SoulBannerKind.checkFailed,
                onAction: _noop,
              ),
              maxWidth: 360,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SoulSaveActions',
      useCases: [
        ...onEachPlatform(
          'Buttons, unsaved changes',
          (_) => frame(
            const SoulSaveActions(
              dirty: true,
              busy: false,
              onSave: _noop,
              onRevert: _noop,
            ),
          ),
        ),
        _framed(
          'Buttons, nothing to save',
          () => const SoulSaveActions(
            dirty: false,
            busy: false,
            onSave: _noop,
            onRevert: _noop,
          ),
        ),
        _framed(
          'Buttons, saving',
          () => const SoulSaveActions(
            dirty: true,
            busy: true,
            onSave: _noop,
            onRevert: _noop,
          ),
        ),
        WidgetbookUseCase(
          name: 'Buttons, German',
          builder: (_) => _german(
            frame(
              const SoulSaveActions(
                dirty: true,
                busy: false,
                onSave: _noop,
                onRevert: _noop,
              ),
            ),
          ),
        ),
        ...onEachPlatform(
          'Revert row, unsaved changes',
          (_) => frame(
            const SoulSaveActions.revertButton(
              dirty: true,
              busy: false,
              onRevert: _noop,
            ),
          ),
        ),
        _framed(
          'Revert row, nothing to save',
          () => const SoulSaveActions.revertButton(
            dirty: false,
            busy: false,
            onRevert: _noop,
          ),
        ),
        ...onEachPlatform(
          'Bar, unsaved changes',
          (_) => _page(text: '$_loaded\nNever be rude.'),
        ),
        _pageCase('Bar, saving', () => _page(text: '$_loaded\nX', busy: true)),
      ],
    ),
    WidgetbookComponent(
      name: 'SoulChangedSheet',
      useCases: [
        _framed('Closed', () => const _Sheet()),
        _framed('Server text open', () => const _Sheet(initiallyOpen: true)),
        _framed(
          'Server text open, long',
          () => _Sheet(initiallyOpen: true, serverText: _paragraphs(4000)),
        ),
        _framed(
          'File gone on the server',
          () => const _Sheet(serverGone: true, serverText: ''),
        ),
        _framed(
          'File gone, server version open',
          () => const _Sheet(
            serverGone: true,
            serverText: '',
            initiallyOpen: true,
          ),
        ),
        _framed(
          'Control and bidi characters in the server text',
          () => const _Sheet(initiallyOpen: true, serverText: _hidden),
        ),
        _framed(
          'As a dialog (Mac and wide windows)',
          () => const _Sheet(dialog: true, initiallyOpen: true),
        ),
        WidgetbookUseCase(
          name: 'Largest text, open',
          builder: (_) =>
              _at(3, frame(const _Sheet(initiallyOpen: true), maxWidth: 390)),
        ),
        WidgetbookUseCase(
          name: 'German',
          builder: (_) =>
              _german(frame(const _Sheet(initiallyOpen: true), maxWidth: 390)),
        ),
        WidgetbookUseCase(
          name: 'Opened from a button',
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showSoulChangedSheet(
                context,
                serverText: _server,
                onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
              ),
              child: const Text('Show the sheet'),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Save and Discard questions',
      useCases: [
        ..._question(
          'Save question',
          (context) => askReplaceSoul(context, profile: _profile),
        ),
        ..._question(
          'Save question, empty text',
          (context) => askReplaceSoul(context, profile: _profile, empty: true),
        ),
        ..._question(
          'Save question, an earlier save may be pending',
          (context) =>
              askReplaceSoul(context, profile: _profile, pendingSaveNote: true),
        ),
        ..._question(
          'Save question, 64-character profile name',
          (context) => askReplaceSoul(context, profile: _longProfile),
        ),
        WidgetbookUseCase(
          name: 'Save question, German',
          builder: (_) => _german(
            openOnShow(
              (context) => askReplaceSoul(
                context,
                profile: _profile,
                pendingSaveNote: true,
              ),
            ),
          ),
        ),
        ..._question(
          'Discard question',
          (context) => askDiscardSoul(context, profile: _profile),
        ),
        WidgetbookUseCase(
          name: 'Discard question, German',
          builder: (_) => _german(
            openOnShow((context) => askDiscardSoul(context, profile: _profile)),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'Page states (composition)',
      useCases: [
        _pageCase(
          'Loading',
          () => pushed(
            Builder(
              builder: (context) => SettingsScaffold(
                title: context.l10n.profilesSoulTitle,
                subtitle: _profile,
                // Save is in the bar, disabled, so it does not shift when the
                // text arrives (a phone; wide layouts keep it under the
                // editor).
                formAction:
                    MediaQuery.sizeOf(context).width >= 900 ||
                        platformChromeOf(context) == PlatformChrome.macos
                    ? null
                    : SoulSaveActions.barAction(
                        context,
                        dirty: false,
                        busy: false,
                        onSave: _noop,
                      ),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      const CircularProgressIndicator.adaptive(),
                      Text(context.l10n.profilesSoulLoading),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ...onEachPlatform('Loaded', (_) => _page()),
        _pageCase(
          'File not set yet',
          () => _page(text: '', baseline: '', fileExists: false),
        ),
        _pageCase('Empty file', () => _page(text: '', baseline: '')),
        _pageCase('Text cleared by the user', () => _page(text: '')),
        _pageCase(
          'Unsaved changes',
          () => _page(text: '$_loaded\n- Never be rude.'),
        ),
        _pageCase(
          'Saving',
          () => _page(
            text: '$_loaded\n- Never be rude.',
            busy: true,
            status: SoulStatusKind.saving,
          ),
        ),
        _pageCase('Saved', () => _page(status: SoulStatusKind.saved)),
        _pageCase(
          'Couldn\'t save',
          () => _page(
            text: '$_loaded\n- Never be rude.',
            banner: SoulBannerKind.saveFailed,
          ),
        ),
        _pageCase(
          'Lost answer',
          () => _page(
            text: '$_loaded\n- Never be rude.',
            banner: SoulBannerKind.lostAnswer,
          ),
        ),
        _pageCase(
          'Checking',
          () => _page(
            text: '$_loaded\n- Never be rude.',
            banner: SoulBannerKind.checking,
            busy: true,
          ),
        ),
        _pageCase(
          'Check failed',
          () => _page(
            text: '$_loaded\n- Never be rude.',
            banner: SoulBannerKind.checkFailed,
          ),
        ),
        _pageCase(
          'Check found the earlier text',
          () => _page(
            text: '$_loaded\n- Never be rude.',
            status: SoulStatusKind.earlierText,
          ),
        ),
        _pageCase(
          'Nothing sent, the check read failed',
          () => _page(
            text: '$_loaded\n- Never be rude.',
            banner: SoulBannerKind.saveCheckFailed,
          ),
        ),
        _pageCase(
          'Long text',
          () => _page(text: _paragraphs(20250), baseline: _paragraphs(20250)),
        ),
        _pageCase(
          'Failed to read',
          () => pushed(
            const _Page(banner: SoulBannerKind.readFailed, hideEditor: true),
          ),
        ),
        _pageCase(
          'Offline',
          () => pushed(
            const _Page(banner: SoulBannerKind.offline, hideEditor: true),
          ),
        ),
        _pageCase(
          'Profile gone',
          () => pushed(
            Builder(
              builder: (context) => SettingsScaffold(
                title: context.l10n.profilesSoulTitle,
                subtitle: _profile,
                body: StateMessage(
                  icon: AppIcons.personOff,
                  title: context.l10n.profilesSoulGoneTitle,
                  detail: context.l10n.profilesSoulGoneDetail,
                ),
              ),
            ),
          ),
        ),
        _pageCase(
          'Old server',
          () => pushed(
            Builder(
              builder: (context) => SettingsScaffold(
                title: context.l10n.profilesSoulTitle,
                subtitle: _profile,
                body: StateMessage(
                  icon: AppIcons.extensionOff,
                  title: context.l10n.profilesSoulUnsupportedTitle,
                  detail: context.l10n.profilesSoulUnsupportedDetail,
                  action: OutlinedButton(
                    onPressed: _noop,
                    child: Text(context.l10n.profilesSoulUnsupportedBack),
                  ),
                ),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Keyboard open',
          builder: (_) => Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
              child: _page(text: '$_loaded\n- Never be rude.'),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text, loaded',
          builder: (_) => _at(3, _page()),
        ),
        ...onEachPlatform(
          'Connection paused (editor read-only, text kept)',
          (_) => _page(
            text: '$_loaded\n- Never be rude.',
            banner: SoulBannerKind.paused,
          ),
        ),
        WidgetbookUseCase(
          name: 'Connection paused, largest text',
          builder: (_) => _at(
            3,
            _page(
              text: '$_loaded\n- Never be rude.',
              banner: SoulBannerKind.paused,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Connection paused, German',
          builder: (_) => _german(
            _page(
              text: '$_loaded\n- Never be rude.',
              banner: SoulBannerKind.paused,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text, with a banner',
          builder: (_) => _at(
            3,
            _page(
              text: '$_loaded\n- Never be rude.',
              banner: SoulBannerKind.lostAnswer,
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'German, with a banner',
          builder: (_) => _german(
            _page(
              text: '$_loaded\n- Never be rude.',
              banner: SoulBannerKind.lostAnswer,
            ),
          ),
        ),
      ],
    ),
  ],
);
