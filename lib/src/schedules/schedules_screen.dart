import 'package:flutter/material.dart';

import 'blueprint_screens.dart';
import 'schedule_detail.dart';
import 'schedule_models.dart';
import 'schedules_controller.dart';
import 'schedules_list.dart';

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
  static const double _wideBreakpoint = 900;

  SchedulesController get _controller => widget.controller;

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
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= _wideBreakpoint;
        return ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final visible = _controller.visibleJobs;
            final selected = _controller.selected;
            final shown = selected ?? (wide ? visible.firstOrNull : null);
            final list = SchedulesList(
              controller: _controller,
              selectedKey: wide ? shown?.key : null,
              onSelect: wide ? _controller.select : _openNarrow,
            );
            return Scaffold(
              appBar: AppBar(
                title: const Text('Schedules'),
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _controller.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _new(wide: wide),
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
              body: wide
                  ? Row(
                      children: [
                        SizedBox(width: 400, child: list),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: shown == null
                              ? const Center(child: Text('Select a task'))
                              : ScheduleDetail(
                                  controller: _controller,
                                  job: shown,
                                  onOpenRun: widget.onOpenRun,
                                ),
                        ),
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
        return Scaffold(
          appBar: AppBar(title: Text(job.title)),
          body: ScheduleDetail(
            controller: controller,
            job: job,
            onOpenRun: onOpenRun,
          ),
        );
      },
    );
  }
}
