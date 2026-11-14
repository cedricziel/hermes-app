import 'package:flutter_otel/flutter_otel.dart' show Span, StatusCode;

import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import 'workspace_models.dart';

/// Which read a `workspace.list` span timed.
enum WorkspaceListKind { catalog, browse, suggest }

/// How a folder move came out, as `workspace.move_outcome` reports it. Fixed
/// names, never a folder.
enum WorkspaceMoveOutcome {
  changed,
  unchanged,
  couldNotConfirm,
  folderMissing,
  chatGone,
  profileGone,
  unsupported,
}

/// A fixed name for how a call came to an end.
String workspaceResultName(WorkspacesResult<Object?> result) =>
    switch (result) {
      WorkspacesOk() => 'ok',
      WorkspacesUnsupported() => 'unsupported',
      WorkspacesFailed(:final kind) => switch (kind) {
        WorkspacesFailure.unreachable => 'unreachable',
        WorkspacesFailure.notFound => 'not_found',
        WorkspacesFailure.notAllowed ||
        WorkspacesFailure.outsideBoundary => 'forbidden',
        WorkspacesFailure.unknownProfile => 'unknown_profile',
        WorkspacesFailure.sessionGone => 'session_gone',
        _ => 'failed',
      },
    };

/// What the working-folder feature tells telemetry: breadcrumbs
/// `workspace.picker.opened`, `workspace.chosen` and
/// `workspace.move.confirmed`, and spans `workspace.list` and
/// `workspace.move`. (`workspace.move_outcome` and `workspace.cwd_mismatch`
/// are log events of the chat controller.)
///
/// Every value is a fixed name, a flag or a count. A path, folder or project
/// name, branch or profile name never reaches it, nor does a request URL or
/// the server's text. Nothing here throws.
class WorkspaceTelemetry {
  const WorkspaceTelemetry([
    this.connection = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
  ]);

  static const none = WorkspaceTelemetry();

  final ConnectionTelemetry connection;
  final Breadcrumbs breadcrumbs;

  /// The picker was opened, to choose a folder for a new chat or to move one.
  void pickerOpened({required bool move}) => _quiet(
    () =>
        breadcrumbs('workspace.picker.opened', {'mode': move ? 'move' : 'new'}),
  );

  /// A folder was chosen: its [source], or `default` for the server default.
  void chosen(WorkspaceChoiceSource? source) => _quiet(
    () =>
        breadcrumbs('workspace.chosen', {'source': source?.name ?? 'default'}),
  );

  Span? startList(WorkspaceListKind kind) =>
      _start('workspace.list', {'kind': kind.name});

  /// Ends the `workspace.list` span with how the read came to an end and,
  /// for a catalog, how many projects and git roots it held.
  void endList(
    Span? span,
    WorkspacesResult<Object?> result, {
    int? projects,
    int? repos,
  }) => _quiet(() {
    span?.setAttribute('outcome', workspaceResultName(result));
    if (projects != null) span?.setAttribute('projects', projects);
    if (repos != null) span?.setAttribute('repos', repos);
    _finish(span, failed: result is WorkspacesFailed);
  });

  Span? startMove() => _start('workspace.move', const {});

  void endMove(Span? span, WorkspacesResult<Object?> result) => _quiet(() {
    span?.setAttribute('outcome', workspaceResultName(result));
    _finish(span, failed: result is WorkspacesFailed);
  });

  Span? _start(String name, Map<String, Object> attributes) {
    try {
      return connection.tracer?.startSpan(
        name,
        attributes: {...connection.serverAttributes, ...attributes},
      );
    } on Object {
      return null;
    }
  }

  static void _finish(Span? span, {required bool failed}) {
    if (failed) span?.setStatus(StatusCode.error);
    span?.end();
  }

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
