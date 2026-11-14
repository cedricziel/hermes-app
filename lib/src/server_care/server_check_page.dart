import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../theme/app_icons.dart';
import '../widgets/route_dismissal.dart';
import '../widgets/settings_scaffold.dart';
import 'doctor_report.dart';
import 'secure_window.dart';
import 'server_care_controller.dart';
import 'server_check_controller.dart';
import 'update_check_controller.dart' show Elapsed, ElapsedUnit;
import 'update_page.dart' show elapsedText;
import 'widgets/private_surface.dart';
import 'widgets/server_check_body.dart';

/// How long ago [from] was at [now], in the units the page words.
Elapsed elapsedSince(DateTime from, DateTime now) {
  final minutes = now.difference(from).inMinutes;
  if (minutes < 1) return const Elapsed(ElapsedUnit.justNow);
  if (minutes < 60) return Elapsed(ElapsedUnit.minutes, minutes);
  return Elapsed(ElapsedUnit.hours, minutes ~/ 60);
}

/// The page's model of a finished check: problems and warnings first, with
/// Hermes' section as where it listed them, its fixes with the command it
/// quoted, the passed checks by section, and every line no rule matched,
/// exactly as Hermes wrote it.
ServerCheckView serverCheckResultOf(
  DoctorReport report,
  List<String> lines, {
  String? checkedAgo,
  bool incomplete = false,
}) {
  final problems = <CheckFinding>[];
  final warnings = <CheckFinding>[];
  final passed = <CheckPassedGroup>[];
  final unknown = <CheckUnknownLine>[];
  for (final section in report.sections) {
    final ok = <String>[];
    for (final item in section.items) {
      final finding = CheckFinding(
        title: item.text,
        detail: item.detail,
        note: item.note,
        group: section.title,
      );
      switch (item.kind) {
        case DoctorItemKind.problem:
          problems.add(finding);
        case DoctorItemKind.warning:
          warnings.add(finding);
        case DoctorItemKind.passed:
          ok.add(
            item.detail == null ? item.text : '${item.text} · ${item.detail}',
          );
      }
    }
    if (ok.isNotEmpty) {
      passed.add(CheckPassedGroup(title: section.title, items: ok));
    }
    for (final line in section.other) {
      unknown.add(CheckUnknownLine(text: line, group: section.title));
    }
  }
  if (report.sections.isEmpty && !report.allPassed) {
    // Output with no section in it at all is shown whole, as written, minus
    // what the report already lists as fixes.
    unknown.addAll([
      for (final line in DoctorReport.leftover(lines, report))
        CheckUnknownLine(text: line),
    ]);
  } else {
    for (final line in report.trailing) {
      unknown.add(CheckUnknownLine(text: line));
    }
  }
  return ServerCheckView.result(
    problems: problems,
    warnings: warnings,
    fixes: [
      for (final fix in report.fixes)
        CheckFix(text: fix, command: commandInFix(fix)),
    ],
    passed: passed,
    unknown: unknown,
    allPassed: report.allPassed,
    checkedAgo: checkedAgo,
    incomplete: incomplete,
  );
}

/// Asks Hermes to look for problems in its setup and shows what it found.
///
/// The check belongs to the shell, so leaving the page does not stop it and
/// coming back shows where it is. Its output can hold paths and
/// configuration names, so the page keeps nothing of its own, marks the
/// Android window secure while it is on screen and draws a blank surface
/// while the app is inactive on a phone. The shell drops the output when App
/// Lock covers the app, on sign-out, server change and profile switch.
class ServerCheckPage extends StatefulWidget {
  const ServerCheckPage({super.key, this.runOnOpen = false});

  /// Starts a check as the page opens, unless one is going or waiting. The
  /// buttons that offer a check ("Run a check") set it; the row that shows
  /// the last result does not.
  final bool runOnOpen;

  @override
  State<ServerCheckPage> createState() => _ServerCheckPageState();
}

class _ServerCheckPageState extends State<ServerCheckPage> {
  late final ServerCareController _care;
  late final ServerCheckController _check;
  late final Listenable _changes;
  void Function()? _releaseSecure;
  bool _left = false;

  // A run asked for before any profile was known: it goes out once, when one is.
  bool _runWhenKnown = false;

  @override
  void initState() {
    super.initState();
    _care = context.read<ServerCareController>();
    _check = context.read<ServerCheckController>();
    _changes = Listenable.merge([_check, _care]);
    _releaseSecure = SecureWindow.instance.hold();
    // Anything that throws from here on must not leave the window secure.
    try {
      _check.addListener(_checkChanged);
      _care.addListener(_checkChanged);
      // A route found missing while the page was closed: nothing to show.
      if (_missing) {
        _leave();
        return;
      }
      if (widget.runOnOpen && _check.phase != CheckPhase.timedOut) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_check.busy) _run();
        });
      }
    } on Object {
      _releaseSecure?.call();
      _releaseSecure = null;
      rethrow;
    }
  }

  @override
  void dispose() {
    _releaseSecure?.call();
    _check.removeListener(_checkChanged);
    _care.removeListener(_checkChanged);
    super.dispose();
  }

  bool get _missing =>
      !_care.offers(CarePart.check) ||
      (_check.phase == CheckPhase.failed &&
          _check.failure == CheckFailure.unsupported);

  /// The server has no route to run a check: the shell has hidden the row
  /// (the controller reported it), and the page closes rather than explain a
  /// missing part.
  void _checkChanged() {
    if (_left) return;
    if (_missing) {
      _leave();
      return;
    }
    if (_runWhenKnown && _care.profile != null) {
      _runWhenKnown = false;
      _run();
    }
  }

  void _leave() {
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _care.reportUnsupported(CarePart.check);
      _check.dismiss();
      dismissRoute(context);
    });
  }

  void _run() {
    final profile = _care.profile;
    if (profile == null) {
      // No profile is known yet: look one up, and run once it is.
      _runWhenKnown = true;
      _care.refresh();
      return;
    }
    _check.run(profile: profile);
  }

  ServerCheckView _view(AppLocalizations l10n) {
    final check = _check;
    switch (check.phase) {
      case CheckPhase.idle:
        return const ServerCheckView.intro();
      case CheckPhase.starting || CheckPhase.running:
        return ServerCheckView.running(checksSoFar: check.progress);
      case CheckPhase.timedOut:
        return const ServerCheckView.timeout();
      case CheckPhase.failed:
        final partial = check.report;
        if (check.failure == CheckFailure.incomplete && partial != null) {
          return serverCheckResultOf(partial, check.lines, incomplete: true);
        }
        return ServerCheckView.failed(
          failure: switch (check.failure) {
            CheckFailure.refused => ServerCheckFailureKind.refused,
            CheckFailure.exited => ServerCheckFailureKind.exited,
            _ => ServerCheckFailureKind.unreachable,
          },
          message: check.message,
        );
      case CheckPhase.finished:
        final at = check.finishedAt;
        return serverCheckResultOf(
          check.report!,
          check.lines,
          checkedAgo: at == null
              ? null
              : elapsedText(l10n, elapsedSince(at, DateTime.now())),
        );
    }
  }

  @override
  Widget build(BuildContext context) => PrivateSurface(
    child: ListenableBuilder(
      listenable: _changes,
      builder: (context, _) {
        final l10n = context.l10n;
        final profile = _check.profile ?? _care.profile;
        final busy = _check.busy;
        return SettingsScaffold(
          title: l10n.serverCareCheckPageTitle,
          subtitle: profile,
          previousTitle: l10n.serverCareTitle,
          actions: [
            if (_check.phase == CheckPhase.finished)
              SettingsBarAction(
                key: const Key('check-refresh'),
                label: l10n.serverCareCheckRunAgain,
                icon: AppIcons.refresh,
                onPressed: busy ? null : _run,
              ),
          ],
          body: ServerCheckBody(
            view: _view(l10n),
            onRun: busy ? null : _run,
            onKeepWaiting: _check.keepWaiting,
            onDismiss: _check.dismiss,
          ),
        );
      },
    ),
  );
}
