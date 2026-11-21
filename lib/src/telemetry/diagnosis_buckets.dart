/// Coarse, fixed-name buckets for the reply-loss diagnosis events
/// (`app.lifecycle`, `gateway.socket_closed`, `gateway.reconnect_attempt`,
/// `chat.reply.ended`, ...). A value an event carries is one of these names or
/// a small count, never text, an id or a measured number that could single a
/// person out. See `docs/architecture/telemetry.md`.
library;

/// Every name [awayBucket] returns.
const kAwayBuckets = {'under_5s', '5_30s', '30_120s', '120_600s', 'over_600s'};

/// How long the app was in the background or inactive.
String awayBucket(Duration away) {
  final seconds = away.inSeconds;
  if (seconds < 5) return 'under_5s';
  if (seconds < 30) return '5_30s';
  if (seconds < 120) return '30_120s';
  if (seconds < 600) return '120_600s';
  return 'over_600s';
}

/// Every name [durationBucket] returns.
const kDurationBuckets = {'under_1s', '1_5s', '5_20s', '20_60s', 'over_60s'};

/// How long one step took (a reconnect attempt, a reply).
String durationBucket(Duration duration) {
  final ms = duration.inMilliseconds;
  if (ms < 1000) return 'under_1s';
  if (ms < 5000) return '1_5s';
  if (ms < 20000) return '5_20s';
  if (ms < 60000) return '20_60s';
  return 'over_60s';
}

/// Every name [countBucket] returns.
const kCountBuckets = {'0', '1', '2_3', '4_plus'};

/// A small count, such as the prompts waiting in a queue.
String countBucket(int count) {
  if (count <= 0) return '0';
  if (count == 1) return '1';
  if (count <= 3) return '2_3';
  return '4_plus';
}

/// Every name [closeCodeBucket] returns.
const kCloseCodeBuckets = {
  'none',
  'normal',
  'going_away',
  'abnormal',
  'protocol',
  'policy',
  'server_error',
  'app_busy',
  'app_other',
  'other',
};

/// What a WebSocket close code says, or `none` when the socket ended with no
/// code (a local drop, a silent socket, an error). `4009` is the gateway's
/// "busy".
String closeCodeBucket(int? code) {
  if (code == null) return 'none';
  return switch (code) {
    1000 => 'normal',
    1001 => 'going_away',
    1005 || 1006 => 'abnormal',
    1002 || 1003 || 1007 || 1009 || 1010 => 'protocol',
    1008 => 'policy',
    1011 || 1012 || 1013 || 1014 => 'server_error',
    4009 => 'app_busy',
    >= 4000 && < 5000 => 'app_other',
    _ => 'other',
  };
}
