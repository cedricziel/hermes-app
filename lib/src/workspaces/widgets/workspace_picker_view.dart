import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/files_lazy_list.dart';
import '../../files/widgets/files_metrics.dart';
import '../../files/widgets/server_path_text.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/busy_bar.dart';
import '../../widgets/grouped_choice_row.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/settings_scaffold.dart';
import '../../widgets/settings_search_field.dart';
import '../../widgets/state_message.dart';
import 'workspace_widget_support.dart';

/// One folder in the picker.
class WorkspacePickerRow {
  const WorkspacePickerRow({
    required this.id,
    required this.title,
    required this.path,
    this.label,
    this.chatCount,
    this.isNew = false,
    this.isCurrent = false,
    this.projectName,
  });

  /// What [WorkspacePickerView.onPick] gets back.
  final String id;

  /// The row's title: a project's name, or a folder's.
  final String title;

  /// The folder's full path on the server, shown cut in the middle.
  final String path;

  /// A project's folder label (a project with several folders).
  final String? label;

  /// How many chats ran in the folder (a recent folder).
  final int? chatCount;

  /// Found by the scan just now.
  final bool isNew;

  /// The folder the chat being moved runs in now.
  final bool isCurrent;

  /// On the Server default row: the project the default folder belongs to.
  final String? projectName;
}

/// Where the projects read stands.
enum WorkspacePickerCatalog {
  /// Loading: the Server default row works at once and the rest is a
  /// labelled skeleton.
  loading,
  ready,

  /// The projects could not be read (or took longer than 10 s); browsing and
  /// typing still work.
  projectsFailed,

  /// The profile no longer exists on the server.
  unknownProfile,
}

/// How a scan ended, for the message under the list.
enum WorkspacePickerScanOutcome {
  /// New folders were found: [WorkspacePickerView.scanFound] of them.
  found,

  /// Nothing new was found.
  nothingNew,

  /// The profile has no folders to scan; they are set on the server.
  nothingToScan,

  /// No answer in 10 s; the list keeps what it had.
  tooSlow,
}

/// Searching starts to help when the project and recent rows together are more
/// than this many.
const int kWorkspacePickerSearchThreshold = 8;

/// The folder picker of a chat: "Choose a folder" over "On your server", in a
/// sheet (a dialog on a Mac and in wide windows).
///
/// The bar leads with Cancel (iOS) or a close button (Material), and has a
/// More menu holding "Look for projects on your server" when [scanAvailable].
/// The Mac's bar has no Cancel, so its dialog gets a Cancel button at the
/// foot. The list has Server default, Projects, Recent and "Somewhere else"
/// (Browse and Type a path), in rows that show a check (Apple) or a radio
/// (Material) for [selectedId]. Paths are cut in the middle; at a large text
/// size they wrap. A search field shows when the project and recent rows
/// together are more than [kWorkspacePickerSearchThreshold] (or a query is
/// set); the host passes the rows already filtered by [query], and Server
/// default and "Somewhere else" never go away.
///
/// A scan shows a busy bar under the bar while the list stays usable; its
/// outcome is a line under the list ([scanOutcome]). It takes plain values and
/// callbacks.
class WorkspacePickerView extends StatelessWidget {
  const WorkspacePickerView({
    super.key,
    required this.selectedId,
    required this.serverDefault,
    this.projects = const [],
    this.recent = const [],
    this.catalog = WorkspacePickerCatalog.ready,
    this.offline = false,
    this.browseLocked = false,
    this.query = '',
    this.scanAvailable = false,
    this.scanning = false,
    this.scanOutcome,
    this.scanFound = 0,
    this.onPick,
    this.onBrowse,
    this.onType,
    this.onTryAgain,
    this.onQueryChanged,
    this.onScan,
    this.onCancel,
  });

  final String selectedId;
  final WorkspacePickerRow serverDefault;
  final List<WorkspacePickerRow> projects;
  final List<WorkspacePickerRow> recent;
  final WorkspacePickerCatalog catalog;

  /// No connection: a neutral banner, and Browse and Type are disabled with
  /// their reason.
  final bool offline;

  /// The server only lets the app browse its own folders: Browse is hidden
  /// and a note says so.
  final bool browseLocked;
  final String query;

  /// The server can scan: the More menu has "Look for projects on your
  /// server".
  final bool scanAvailable;
  final bool scanning;
  final WorkspacePickerScanOutcome? scanOutcome;

  /// With [WorkspacePickerScanOutcome.found], how many new folders.
  final int scanFound;
  final ValueChanged<String>? onPick;
  final VoidCallback? onBrowse;
  final VoidCallback? onType;
  final VoidCallback? onTryAgain;
  final ValueChanged<String>? onQueryChanged;
  final VoidCallback? onScan;

  /// Closes the picker (the Mac's Cancel button); the bar's own Cancel pops
  /// the route.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chrome = platformChromeOf(context);
    final mac = chrome == PlatformChrome.macos;
    final showSearch =
        catalog == WorkspacePickerCatalog.ready &&
        (projects.length + recent.length > kWorkspacePickerSearchThreshold ||
            query.isNotEmpty);
    final toast = _toast(l10n);
    return SettingsScaffold(
      title: l10n.workspacesPickerTitle,
      subtitle: l10n.workspacesPickerSubtitle,
      cancel: true,
      search: showSearch
          ? SettingsSearch(
              query: query,
              hint: l10n.workspacesPickerSearchHint,
              onChanged: onQueryChanged ?? (_) {},
            )
          : null,
      actions: [
        if (scanAvailable)
          SettingsBarAction.menu(
            key: const Key('workspace-picker-more'),
            label: l10n.workspacesPickerMore,
            icon: AppIcons.more,
            menu: (_) => [
              AdaptiveMenuItem<void>(
                enabled: !scanning,
                onTap: onScan,
                child: Text(l10n.workspacesPickerScan),
              ),
            ],
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scanning) const BusyBar(),
          Expanded(
            child: catalog == WorkspacePickerCatalog.unknownProfile
                ? StateMessage(
                    icon: AppIcons.error,
                    title: l10n.workspacesPickerUnknownProfile,
                    detail: l10n.workspacesPickerUnknownProfileDetail,
                  )
                : _PickerList(view: this),
          ),
          ?toast,
          if (mac) _MacFoot(onCancel: onCancel),
        ],
      ),
    );
  }

  Widget? _toast(AppLocalizations l10n) {
    final outcome = scanOutcome;
    if (outcome == null || scanning) return null;
    final text = switch (outcome) {
      WorkspacePickerScanOutcome.found => l10n.workspacesScanFound(scanFound),
      WorkspacePickerScanOutcome.nothingNew => l10n.workspacesScanNothingNew,
      WorkspacePickerScanOutcome.nothingToScan =>
        l10n.workspacesScanNothingToScan,
      WorkspacePickerScanOutcome.tooSlow => l10n.workspacesScanTooSlow,
    };
    return _ScanToast(
      key: const Key('workspace-scan-toast'),
      text: text,
      icon: switch (outcome) {
        WorkspacePickerScanOutcome.found => AppIcons.checkCircle,
        WorkspacePickerScanOutcome.tooSlow => AppIcons.warning,
        _ => AppIcons.info,
      },
      warning: outcome == WorkspacePickerScanOutcome.tooSlow,
    );
  }
}

/// The scan's outcome, under the list: an icon and words, announced when it
/// appears.
class _ScanToast extends StatelessWidget {
  const _ScanToast({
    super.key,
    required this.text,
    required this.icon,
    required this.warning,
  });

  final String text;
  final AppIconSet icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final metrics = GroupedMetrics.of(context);
    final color = warning ? colors.warning : scheme.onSurface;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.gutter,
          4,
          metrics.gutter,
          metrics.gutter / 2,
        ),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: text,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: AppIcon(
                        icon,
                        size: workspaceGlyphSize(
                          context,
                          metrics.subtitleSize + 2,
                        ),
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: metrics.subtitleSize,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MacFoot extends StatelessWidget {
  const _MacFoot({required this.onCancel});

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton(
          key: const Key('workspace-picker-cancel'),
          onPressed: onCancel ?? () => Navigator.maybePop(context),
          style: FilesMetrics.macos.buttonStyle(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ),
    ),
  );
}

/// The list: a card per section, built row by row so a long Recent list costs
/// a screenful.
class _PickerList extends StatelessWidget {
  const _PickerList({required this.view});

  final WorkspacePickerView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final catalog = view.catalog;
    final filtering = view.query.isNotEmpty;
    final empty = view.projects.isEmpty && view.recent.isEmpty;
    final browse = !view.browseLocked;
    final disabled = view.offline;
    final footer = disabled
        ? l10n.workspacesElsewhereOffline
        : view.browseLocked
        ? l10n.workspacesElsewhereLocked
        : null;
    return RadioGroup<String>(
      groupValue: view.selectedId,
      onChanged: (id) {
        if (id != null) view.onPick?.call(id);
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final side = math.max(
            metrics.gutter,
            (box.maxWidth - metrics.maxWidth) / 2,
          );
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 0, side, 32),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    if (view.offline)
                      _box(
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AppBanner(
                            tone: AppBannerTone.neutral,
                            icon: kWorkspaceOfflineIcon,
                            title: l10n.workspacesPickerOffline,
                          ),
                        ),
                      ),
                    if (catalog == WorkspacePickerCatalog.projectsFailed)
                      _box(
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AppBanner(
                            tone: AppBannerTone.warning,
                            title: l10n.workspacesPickerProjectsFailed,
                            action: TextButton(
                              onPressed: view.onTryAgain,
                              style: FilesMetrics.of(context).buttonStyle(),
                              child: Text(l10n.workspacesTryAgain),
                            ),
                          ),
                        ),
                      ),
                    ..._section(context, null, [view.serverDefault]),
                    if (catalog == WorkspacePickerCatalog.loading)
                      ..._loadingSection(context),
                    if (catalog == WorkspacePickerCatalog.ready) ...[
                      if (empty && !view.offline)
                        _box(
                          _Note(
                            filtering
                                ? l10n.workspacesPickerNoMatch(view.query)
                                : l10n.workspacesPickerEmpty,
                          ),
                        ),
                      if (view.projects.isNotEmpty)
                        ..._section(
                          context,
                          l10n.workspacesSectionProjects,
                          view.projects,
                        ),
                      if (view.recent.isNotEmpty)
                        ..._section(
                          context,
                          l10n.workspacesSectionRecent,
                          view.recent,
                        ),
                    ],
                    ..._elsewhere(context, browse, disabled, footer),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _box(Widget child) => SliverToBoxAdapter(child: child);

  /// A header and a card of rows built on demand.
  List<Widget> _section(
    BuildContext context,
    String? header,
    List<WorkspacePickerRow> rows,
  ) {
    final metrics = GroupedMetrics.of(context);
    final indent = GroupedChoiceRow.dividerIndent(context);
    return [
      _box(_Header(header, topGap: header == null ? 8 : metrics.sectionGap)),
      SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) => CardSlice(
          first: i == 0,
          last: i == rows.length - 1,
          radius: metrics.radius,
          dividerIndent: indent ?? metrics.rowPadding,
          child: _PickerRowTile(
            key: ValueKey(rows[i].id),
            row: rows[i],
            serverDefault: identical(rows[i], view.serverDefault),
          ),
        ),
      ),
    ];
  }

  List<Widget> _loadingSection(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    return [
      _box(_Header(l10n.workspacesSectionProjects, topGap: metrics.sectionGap)),
      _box(
        _Card(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.rowPadding,
              vertical: 6,
            ),
            child: LoadingSkeleton(label: l10n.workspacesPickerLoading),
          ),
        ),
      ),
    ];
  }

  List<Widget> _elsewhere(
    BuildContext context,
    bool browse,
    bool disabled,
    String? footer,
  ) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final rows = <Widget>[
      if (browse)
        _ActionRow(
          key: const Key('workspace-picker-browse'),
          icon: AppIcons.folder,
          title: l10n.workspacesPickerBrowse,
          enabled: !disabled,
          reason: footer,
          onTap: view.onBrowse,
        ),
      _ActionRow(
        key: const Key('workspace-picker-type'),
        icon: const AppIconSet(
          Icons.keyboard_outlined,
          CupertinoIcons.keyboard,
        ),
        title: l10n.workspacesPickerType,
        enabled: !disabled,
        reason: footer,
        onTap: view.onType,
      ),
    ];
    return [
      _box(
        _Header(l10n.workspacesSectionElsewhere, topGap: metrics.sectionGap),
      ),
      SliverList.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) => CardSlice(
          first: i == 0,
          last: i == rows.length - 1,
          radius: metrics.radius,
          dividerIndent: metrics.rowPadding,
          child: rows[i],
        ),
      ),
      if (footer != null)
        _box(
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              6,
              metrics.rowPadding,
              0,
            ),
            child: Text(
              footer,
              style: TextStyle(fontSize: metrics.footerSize, color: muted),
            ),
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text, {required this.topGap});

  final String? text;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final text = this.text;
    return Padding(
      padding: EdgeInsets.only(
        top: topGap,
        left: metrics.rowPadding,
        right: metrics.rowPadding,
        bottom: text == null ? 0 : 6,
      ),
      child: text == null
          ? null
          : Semantics(
              header: true,
              child: Text(
                metrics.headerUppercase ? text.toUpperCase() : text,
                style: TextStyle(
                  fontSize: metrics.headerSize,
                  fontWeight: metrics.headerWeight,
                  color: context.hermesColors.subtleText,
                ),
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(GroupedMetrics.of(context).radius),
      ),
      child: child,
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.hermesColors.subtleText),
      ),
    ),
  );
}

class _PickerRowTile extends StatelessWidget {
  const _PickerRowTile({
    super.key,
    required this.row,
    required this.serverDefault,
  });

  final WorkspacePickerRow row;
  final bool serverDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final large = isLargeText(context);
    final meta = [
      if (serverDefault) l10n.workspacesTagServerDefault,
      if (serverDefault && row.projectName != null) row.projectName!,
      if (row.label != null) row.label!,
      if (row.chatCount != null) l10n.workspacesMetaChats(row.chatCount!),
      if (row.isNew) l10n.workspacesMetaNew,
      if (row.isCurrent) l10n.workspacesMetaCurrent,
    ].join(' · ');
    final style = TextStyle(fontSize: metrics.subtitleSize, color: muted);
    return GroupedChoiceRow<String>(
      value: row.id,
      title: workspaceShortName(row.title, max: 48),
      titleMaxLines: large ? null : 1,
      meta: meta.isEmpty ? null : meta,
      details: [
        Semantics(
          label: row.path,
          excludeSemantics: true,
          child: large
              ? Text(
                  row.path,
                  style: style.copyWith(fontFamily: kServerPathFont),
                )
              : PathCutText(row.path, style: style),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onTap,
    this.reason,
  });

  final AppIconSet icon;
  final String title;
  final bool enabled;
  final VoidCallback? onTap;

  /// Why the row is disabled; read as part of its name, since a hint does not
  /// reach VoiceOver on macOS.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final row = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GroupedRow(
        title: title,
        titleMaxLines: isLargeText(context) ? null : 1,
        leading: AppIcon(icon),
        chevron: true,
        enabled: enabled,
        onTap: onTap ?? () {},
      ),
    );
    if (enabled || reason == null) return row;
    return Semantics(
      button: true,
      enabled: false,
      label: '$title. $reason',
      excludeSemantics: true,
      child: row,
    );
  }
}
