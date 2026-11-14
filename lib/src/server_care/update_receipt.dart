import 'json_read.dart';

enum UpdateOutcome {
  running,
  success,
  partial,
  failed,
  refused,
  interrupted,
  other,
}

UpdateOutcome _outcome(String? raw) => switch (raw) {
  'running' => UpdateOutcome.running,
  'success' => UpdateOutcome.success,
  'partial' => UpdateOutcome.partial,
  'failed' => UpdateOutcome.failed,
  'refused' => UpdateOutcome.refused,
  'interrupted' => UpdateOutcome.interrupted,
  _ => UpdateOutcome.other,
};

/// A step the person still has to take after an update, with Hermes' reason.
class UpdateFollowup {
  const UpdateFollowup({this.step, this.reason});

  final String? step;
  final String? reason;
}

/// The compact `summary` of `GET /api/hermes/update/receipt`. The receipt is
/// root-wide, so a caller credits it only when [actionId] is the one it
/// started.
class UpdateReceiptSummary {
  const UpdateReceiptSummary({
    required this.outcome,
    this.actionId,
    this.postVersion,
    this.preSha,
    this.postSha,
    this.userAction,
    this.followups = const [],
  });

  static UpdateReceiptSummary? parse(Object? json) {
    final summary = readMap(readMap(json)?['summary']);
    if (summary == null) return null;
    UpdateFollowup? followup(Object? raw) {
      final map = readMap(raw);
      if (map == null) return null;
      return UpdateFollowup(
        step: readString(map['step']),
        reason: readString(map['reason']),
      );
    }

    return UpdateReceiptSummary(
      outcome: _outcome(readString(summary['outcome'])),
      actionId: readString(summary['action_id']),
      postVersion: readString(summary['post_version']),
      preSha: readString(summary['pre_sha']),
      postSha: readString(summary['post_sha']),
      userAction: followup(summary['user_action']),
      followups: [
        for (final f in (summary['followups'] as List? ?? const []))
          ?followup(f),
      ],
    );
  }

  final UpdateOutcome outcome;
  final String? actionId;
  final String? postVersion;
  final String? preSha;
  final String? postSha;
  final UpdateFollowup? userAction;
  final List<UpdateFollowup> followups;
}

/// The answer to `POST /api/hermes/update`.
sealed class UpdateStart {
  const UpdateStart();

  static UpdateStart? parse(Object? json) {
    final root = readMap(json);
    if (root == null) return null;
    if (readBool(root['ok']) == true) {
      return UpdateStarted(
        actionId: readString(root['action_id']),
        alreadyRunning: readBool(root['already_running']) ?? false,
      );
    }
    final command = readString(root['update_command']);
    return UpdateRefused(
      code: readString(root['error']),
      message: readString(root['message']),
      command: command == null || command.isEmpty ? null : command,
    );
  }
}

final class UpdateStarted extends UpdateStart {
  const UpdateStarted({this.actionId, this.alreadyRunning = false});

  final String? actionId;
  final bool alreadyRunning;
}

/// Hermes refused with HTTP 200 and `ok: false`: [code] is one of
/// `commit-build`, `dashboard_update_managed_externally` and the like.
final class UpdateRefused extends UpdateStart {
  const UpdateRefused({this.code, this.message, this.command});

  final String? code;
  final String? message;
  final String? command;
}
