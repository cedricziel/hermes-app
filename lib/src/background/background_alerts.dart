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
import '../notifications/request_notifications.dart';
import '../schedules/schedule_alerts.dart';
import '../schedules/schedule_baseline.dart';
import '../surfaces/chat_hints.dart' show kUnnamedChatLabel;
import 'background_refresh.dart';
import 'running_replies.dart';

/// The longest one request of these steps may take, so that a step with
/// several in a row still ends within [kBackgroundStepBudget].
const kAlertLookupBudget = Duration(seconds: 4);

/// The longest the active profile may take to be named in a notification.
const _activeLookup = Duration(seconds: 2);

/// The `session.active_list` statuses of a session whose turn has not ended.
const _turnStatuses = {
  'starting',
  'waiting',
  'working',
  'streaming',
  'resuming',
};

/// Whether a step says nothing: notifications are off, or the app is in
/// front and announces by itself.
Future<bool> _quiet(BackgroundContext context) async =>
    !context.notificationsOn || await context.isAppInFront();

/// How a remembered chat's check ended.
enum _Verdict { announced, nothingToSay, unreadable }

/// Announces the chats the app remembered as replying when it left, once
/// their session has ended its turn and the stored chat shows an answer.
///
/// Only positive evidence announces: the session is listed with its turn
/// ended (`idle`), and the newest stored message is the assistant's own text.
/// A session that is no longer listed, one with a status this does not know,
/// and a chat that ends on the prompt or on a tool call (a turn Hermes lost,
/// or someone stopped) are forgotten without a word, since nothing says the
/// reply was completed. A chat whose history cannot be read is kept for the
/// next run.
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
    if (await _quiet(context)) return const StepCounts();
    final now = _now();
    final remembered = await _running.read();
    bool expired(RunningReply reply) =>
        now.difference(reply.since) > kRunningReplyLifetime;
    final stale = remembered.where(expired).toList();
    if (stale.isNotEmpty) await _running.forget(stale);
    final current = remembered.where((reply) => !expired(reply)).toList();
    if (current.isEmpty) return const StepCounts();

    final profiles = {for (final reply in current) reply.profile};
    final statuses = {
      for (final (profile, status) in await Future.wait([
        for (final profile in profiles) _statuses(context, profile),
      ]))
        profile: status,
    };
    final ended = <RunningReply>[];
    final dropped = <RunningReply>[];
    for (final reply in current) {
      // A profile that could not be read tells nothing about its chats.
      final live = statuses[reply.profile];
      if (live == null) continue;
      final status = live[reply.threadId];
      if (_turnStatuses.contains(status)) continue;
      (status == 'idle' ? ended : dropped).add(reply);
    }
    final verdicts = await Future.wait([
      for (final reply in ended) _announce(context, reply),
    ]);
    // After the notifications: a run cut off in between posts the same
    // per-chat notification again, which replaces the first.
    await _running.forget([
      ...dropped,
      for (var i = 0; i < ended.length; i++)
        if (verdicts[i] != _Verdict.unreadable) ended[i],
    ]);
    final announced = verdicts.where((v) => v == _Verdict.announced).length;
    return StepCounts(repliesFinished: announced);
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

  Future<_Verdict> _announce(
    BackgroundContext context,
    RunningReply reply,
  ) async {
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
    if (page == null) return _Verdict.unreadable;
    final last = page.messages.lastOrNull;
    final preview = last?.role == ChatRole.assistant
        ? replyPreview(last!.content)
        : '';
    if (preview.isEmpty) return _Verdict.nothingToSay;
    // Before the notification, so that the app finds it whenever it returns.
    await _running.markAnnounced([reply]);
    await context.notifications.show(
      AttentionNotification(
        threadId: reply.threadId,
        profile: reply.profile,
        title: thread?.title ?? kUnnamedChatLabel,
        body: await context.appLockOn() ? kReplyReadyBody : preview,
        bodyIsPlainText: true,
        category: replyReadyCategory,
      ),
    );
    return _Verdict.announced;
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
    if (await _quiet(context)) return const StepCounts();
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
    final account = context.hermes.accountKey;
    final pass = runsSince(await _baseline.read(account), jobs);
    final unmuted = [
      for (final job in pass.ran)
        if (!settings.isMuted(job.key)) job,
    ];
    if (unmuted.isNotEmpty) {
      final active = await _quietly(
        () async => (await repositories.profiles.loadActive()).active,
        _activeLookup,
      );
      for (final alert in alertsFor(unmuted, activeProfile: active)) {
        await context.notifications.show(alert);
      }
    }
    // After the notifications: a run cut off in between announces the same
    // runs again, which replaces their notifications.
    await _baseline.write(account, pass.baseline);
    return StepCounts(schedulesRan: unmuted.length);
  }
}
