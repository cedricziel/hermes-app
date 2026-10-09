import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

import 'blueprint_screens.dart';
import 'schedule_detail.dart';
import 'schedule_models.dart';
import 'schedules_controller.dart';
import '../macos/mac_commands.dart';
import '../shell/shell_navigation.dart';
import 'schedules_list.dart';

import '../widgets/named_icon_button.dart';
import '../widgets/settings_scaffold.dart';
import 'widgets/schedule_filter_menu.dart';
import 'widgets/schedules_mac_toolbar.dart';

/// From this content width the Mac list column is 340 points wide, below it
/// 250.
const double _macWideListWidth = 760;

/// The Schedules destination: the job list, and beside it (or pushed over it
/// on a phone) the selected job.
class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({
    super.key,
    required this.controller,
    required this.onOpenRun,
  });

  final SchedulesController controller;
  final OpenRun onOpenRun;

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  SchedulesController get _controller => widget.controller;

  /// Whether the last layout put the list and the detail side by side.
  bool _split = false;

  @override
  void initState() {
    super.initState();
    if (!_controller.loaded && !_controller.loading) _controller.refresh();
    _controller.addListener(_openRequested);
    // A request made before this screen was built waits for it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequested());
  }

  @override
  void dispose() {
    _controller.removeListener(_openRequested);
    super.dispose();
  }

  Future<void> _openRequested() async {
    final request = _controller.takeOpenRequest();
    if (request == null || request.id.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final wide = _split;
    CronJob? job;
    try {
      job = await _controller.findJob(request.id, profile: request.profile);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that task')),
      );
      return;
    }
    if (!mounted) return;
    if (job == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This task no longer exists')),
      );
      return;
    }
    _controller.jobSaved(job);
    if (!wide) _openNarrow(job);
  }

  void _openNarrow(CronJob job) {
    _controller.select(job);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PushedDetail(
          controller: _controller,
          jobKey: job.key,
          onOpenRun: widget.onOpenRun,
        ),
      ),
    );
  }

  Future<void> _new({required bool wide}) async {
    final names = await _controller.profileNames();
    if (!mounted) return;
    final job = await Navigator.of(context).push<CronJob>(
      MaterialPageRoute(
        builder: (_) => BlueprintGalleryScreen(
          repository: _controller.repository,
          profile: _controller.activeProfile,
          profileNames: names,
        ),
      ),
    );
    if (job == null || !mounted) return;
    _controller.jobSaved(job);
    if (!wide) _openNarrow(job);
  }

  Widget _filterMenu() => ScheduleFilterMenu(
    filter: _controller.filter,
    failingCount: _controller.failingCount,
    onChanged: (filter) => _controller.filter = filter,
  );

  /// The subtitle's menu between the active profile's jobs and every
  /// profile's; none while the active profile is unknown.
  SettingsSubtitleMenu<bool>? _scopeMenu() {
    final profile = _controller.activeProfile;
    if (profile == null) return null;
    return SettingsSubtitleMenu<bool>(
      label: 'Profiles',
      onSelected: (all) => _controller.allProfiles = all,
      itemBuilder: (_) => [
        for (final (all, label) in [
          (false, '$profile (active)'),
          (true, 'All profiles'),
        ])
          CheckedPopupMenuItem(
            value: all,
            checked: _controller.allProfiles == all,
            child: Text(label),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => MacCommandScope(
    commands: {
      MacCommand.newChat: MacCommandHandler(
        () => _new(wide: _split),
        title: 'New Schedule',
      ),
    },
    child: _page(context),
  );

  Widget _page(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final mac = platformChromeOf(context) == PlatformChrome.macos;
        final wide = mac
            ? box.maxWidth >= kMacSplitBreakpoint
            : isWideLayout(context, width: box.maxWidth);
        _split = wide;
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final visible = _controller.visibleJobs;
            final selected = _controller.selected;
            final shown = selected ?? (wide ? visible.firstOrNull : null);
            final list = SchedulesList(
              controller: _controller,
              macLayout: mac && wide,
              selectedKey: wide ? shown?.key : null,
              onSelect: wide ? _controller.select : _openNarrow,
            );
            final detail = shown == null
                ? const Center(child: Text('Select a task'))
                : ScheduleDetail(
                    controller: _controller,
                    job: shown,
                    onOpenRun: widget.onOpenRun,
                  );
            if (mac && wide) {
              return _MacLayout(
                controller: _controller,
                jobCount: visible.length,
                listWidth: box.maxWidth >= _macWideListWidth ? 340 : 250,
                list: list,
                detail: detail,
                filterMenu: _filterMenu(),
                onNew: () => _new(wide: true),
              );
            }
            final ios = platformChromeOf(context) == PlatformChrome.ios;
            final barButton = ios ? SettingsScaffold.appleBarButtonStyle : null;
            final profile = _controller.activeProfile;
            return Scaffold(
              appBar: AppBar(
                toolbarHeight: ios ? kAppleNavBarHeight : 56,
                centerTitle: ios,
                leading: ShellMenu.button(context),
                title: SettingsBarTitle(
                  title: 'Schedules',
                  subtitle: _controller.allProfiles || profile == null
                      ? 'All profiles'
                      : profile,
                  subtitleMenu: _scopeMenu(),
                  ios: ios,
                ),
                actions: [
                  _filterMenu(),
                  NamedIconButton(
                    label: 'Refresh',
                    icon: AppIcons.refresh,
                    style: barButton,
                    onPressed: _controller.refresh,
                  ),
                  NamedIconButton(
                    key: const Key('schedules-new'),
                    label: 'New scheduled task',
                    icon: AppIcons.add,
                    style: barButton,
                    onPressed: () => _new(wide: wide),
                  ),
                  SizedBox(width: ios ? 4 : 8),
                ],
              ),
              body: wide
                  ? Row(
                      children: [
                        SizedBox(width: 400, child: list),
                        const VerticalDivider(width: 1),
                        Expanded(child: detail),
                      ],
                    )
                  : list,
            );
          },
        );
      },
    );
  }
}

/// Schedules in a Mac window: the unified toolbar over the job list column
/// and the selected job.
class _MacLayout extends StatelessWidget {
  const _MacLayout({
    required this.controller,
    required this.jobCount,
    required this.listWidth,
    required this.list,
    required this.detail,
    required this.filterMenu,
    required this.onNew,
  });

  final SchedulesController controller;
  final int jobCount;
  final double listWidth;
  final Widget list;
  final Widget detail;
  final Widget filterMenu;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        SchedulesMacToolbar(
          jobCount: jobCount,
          allProfiles: controller.allProfiles,
          onScopeChanged: (all) => controller.allProfiles = all,
          filterMenu: filterMenu,
          onRefresh: controller.refresh,
          onNew: onNew,
        ),
        Expanded(
          child: Row(
            children: [
              SizedBox(width: listWidth, child: list),
              const VerticalDivider(width: 1),
              Expanded(child: detail),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The detail on a phone, over the list. It closes itself when the job is
/// deleted or gone.
class _PushedDetail extends StatelessWidget {
  const _PushedDetail({
    required this.controller,
    required this.jobKey,
    required this.onOpenRun,
  });

  final SchedulesController controller;
  final String jobKey;
  final OpenRun onOpenRun;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final job = controller.jobs.where((j) => j.key == jobKey).firstOrNull;
        if (job == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return SettingsScaffold(
          title: job.title,
          previousTitle: 'Schedules',
          body: ScheduleDetail(
            controller: controller,
            job: job,
            onOpenRun: onOpenRun,
            showTitle: false,
          ),
        );
      },
    );
  }
}
