/// The `hermes://` link of a chat, in the shape the deep-links change
/// defines. This stands in until its `deepLinkUri` builder is on main.
String chatLink({required String profile, required String id}) =>
    _link('chat', {'profile': profile, 'id': id});

/// The `hermes://` link of the Schedules tab, opened on [jobId].
String scheduleLink({required String profile, required String jobId}) =>
    _link('schedules', {'profile': profile, 'job': jobId});

// Uri.queryParameters would write a space as "+", which Swift's
// URLComponents reads back as a plus.
String _link(String host, Map<String, String> query) {
  final pairs = [
    for (final MapEntry(:key, :value) in query.entries)
      '$key=${Uri.encodeComponent(value)}',
  ];
  return 'hermes://$host?${pairs.join('&')}';
}
