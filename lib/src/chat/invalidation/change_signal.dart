enum InvalidationResource { sessions, schedules, platforms, pairing }

class ChangeSignal {
  const ChangeSignal(this.resource);
  final InvalidationResource resource;

  static ChangeSignal? decode(String event, Object? payload) {
    if (payload is! Map) return null;
    final resource = switch (event) {
      'sessions.changed' => InvalidationResource.sessions,
      'cron.changed' => InvalidationResource.schedules,
      'platforms.changed' => InvalidationResource.platforms,
      'pairing.changed' => InvalidationResource.pairing,
      _ => null,
    };
    return resource == null ? null : ChangeSignal(resource);
  }
}
