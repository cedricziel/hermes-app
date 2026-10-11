/// The steps of a background run that tell the user what happened while the
/// app was away: a reply that finished, and a scheduled task that ran.
///
/// Both do what the app in front does, with the same texts and the same
/// per-chat or per-job notification, so a run the app already announced is
/// replaced rather than added to. Neither starts while the app is in front.
library;

import 'dart:async';

import '../chat/chat_models.dart';
import '../notifications/attention_policy.dart';
import '../notifications/notification_settings.dart';
import '../schedules/schedule_alerts.dart';
import '../schedules/schedule_baseline.dart';
import '../surfaces/chat_hints.dart' show kUnnamedChatLabel;
import 'background_refresh.dart';
import 'running_replies.dart';

/// The longest one request of these steps may take, so that a step with
/// several in a row still ends within [kBackgroundStepBudget].
const kAlertLookupBudget = Duration(seconds: 6);

/// The `session.active_list` statuses of a session whose turn has not ended.
const _turnStatuses = {
  'starting',
  'waiting',
  'working',
  'streaming',
  'resuming',
};

/// Announces the chats the app remembered as replying when it left, once
/// their session no longer runs a turn.
class RunningRepliesStep extends BackgroundStep {
  RunningRepliesStep({
    RunningReplies? running,
    DateTime Function()? now,
    this.lookup = kAlertLookupBudget,
  }) : _running = running ?? RunningReplies(),
       _now = now ?? DateTime.now;

  final RunningReplies _running;
  final DateTime Function() _now;
  final Duration lookup;

  @override
  Future<StepCounts> run(BackgroundContext context) async {
    if (!context.notificationsOn || await context.isAppInFront()) {
      return const StepCounts();
    }
    final now = _now();
    final remembered = await _running.read();
    final stale = [
      for (final reply in remembered)
        if (now.difference(reply.since) > kRunningReplyLifetime) reply,
    ];
    if (stale.isNotEmpty) await _running.forget(stale);
    final current = remembered.where((reply) => !stale.contains(reply));
    if (current.isEmpty) return const StepCounts();

    final profiles = {for (final reply in current) reply.profile};
    final statuses = {
      for (final (profile, status) in await Future.wait([
        for (final profile in profiles) _statuses(context, profile),
      ]))
        profile: status,
    };
    final finished = [
      for (final reply in current)
        // A profile that could not be read tells nothing about its chats.
        if (statuses[reply.profile] case final live?)
          if (!_turnStatuses.contains(live[reply.threadId])) reply,
    ];
    if (finished.isEmpty) return const StepCounts();
    // Before the notifications, so that a failure after them cannot announce
    // a chat twice.
    await _running.forget(finished);
    await Future.wait([
      for (final reply in finished) _announce(context, reply),
    ]);
    return StepCounts(repliesFinished: finished.length);
  }

  /// The status of each live session of [profile] by session key, or null
  /// when the server could not say.
  Future<(String?, Map<String, String>?)> _statuses(
    BackgroundContext context,
    String? profile,
  ) async {
    try {
      final listed = await context
          .request('session.active_list', {'profile': ?profile})
          .timeout(lookup);
      final rows = listed['sessions'];
      return (
        profile,
        {
          if (rows is List)
            for (final row in rows)
              if (row case {
                'session_key': final String key,
                'status': final String status,
              })
                key: status,
        },
      );
    } on Object {
      return (profile, null);
    }
  }

  Future<void> _announce(BackgroundContext context, RunningReply reply) async {
    final chat = context.hermes.repositories.chat;
    final (thread, page) = await (
      _quietly(
        () => chat.loadThread(reply.threadId, profile: reply.profile),
        lookup,
      ),
      _quietly(
        () => chat.loadMessagePage(
          reply.threadId,
          profile: reply.profile,
          limit: 5,
        ),
        lookup,
      ),
    ).wait;
    await context.notifications.show(
      AttentionNotification(
        threadId: reply.threadId,
        profile: reply.profile,
        title: thread?.title ?? kUnnamedChatLabel,
        body: _body(page?.messages.lastOrNull),
      ),
    );
  }

  /// What the app in front says when a reply ends. History does not record a
  /// failure, but a chat that ends on the user's own prompt never got an
  /// answer.
  String _body(ChatMessage? last) {
    if (last == null) return kReplyReadyBody;
    if (last.role == ChatRole.user) return kReplyFailedBody;
    final preview = replyPreview(last.content);
    return preview.isEmpty ? kReplyReadyBody : preview;
  }
}

/// The result of [read], or null when it fails or takes longer than [limit].
Future<T?> _quietly<T>(Future<T?> Function() read, Duration limit) async {
  try {
    return await read().timeout(limit);
  } on Object {
    return null;
  }
}

/// The schedule check of the app in front, for the time it is away: the same
/// runs, settings and mutes, against the baseline the app in front keeps too.
class ScheduleAlertsStep extends BackgroundStep {
  ScheduleAlertsStep({
    ScheduleBaseline? baseline,
    this._settings,
    this.lookup = kAlertLookupBudget,
  }) : _baseline = baseline ?? ScheduleBaseline();

  final ScheduleBaseline _baseline;
  final NotificationSettings? _settings;
  final Duration lookup;

  @override
  Future<StepCounts> run(BackgroundContext context) async {
    if (!context.notificationsOn || await context.isAppInFront()) {
      return const StepCounts();
    }
    final settings = _settings ?? NotificationSettings();
    if (!settings.loaded) await settings.load();
    if (!settings.scheduleAlerts) return const StepCounts();

    final repositories = context.hermes.repositories;
    if (await repositories.cron.availability().timeout(lookup) != true) {
      return const StepCounts();
    }
    final jobs = await repositories.cron
        .listJobs(profile: 'all')
        .timeout(lookup);
    await settings.forgetMutes({for (final job in jobs) job.key});
    final pass = runsSince(await _baseline.read(), jobs);
    // Before the notifications: a baseline that cannot be saved announces
    // nothing now instead of the same runs at every run.
    await _baseline.write(pass.baseline);
    final unmuted = [
      for (final job in pass.ran)
        if (!settings.isMuted(job.key)) job,
    ];
    if (unmuted.isEmpty) return const StepCounts();
    final active = await _quietly(
      () async => (await repositories.profiles.loadActive()).active,
      lookup,
    );
    for (final alert in alertsFor(unmuted, activeProfile: active)) {
      await context.notifications.show(alert);
    }
    return StepCounts(schedulesRan: unmuted.length);
  }
}
