/// The source the messenger plugin saves a delivery under. App-started chats
/// share it, so [kDeliveryIdPrefix] tells a delivery apart.
const kDeliverySource = 'hermes_app';
const kDeliveryIdPrefix = 'hermes-app-';

/// Rows per request, and how many requests one look makes at most.
const kDeliveryPageSize = 20;
const kDeliveryPages = 3;

/// A chat a Hermes profile delivered to the Hermes App inbox, as the session
/// list reports it.
class AgentDelivery {
  const AgentDelivery({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.messageCount,
    required this.unread,
  });

  final String id;
  final String? title;

  /// Seconds since the epoch.
  final double startedAt;
  final int messageCount;
  final bool unread;

  /// The delivery in a session-list [row], or null when the row is not one or
  /// lacks what a look needs.
  static AgentDelivery? fromRow(Map<String, dynamic> row) {
    final id = row['id'];
    final startedAt = row['started_at'];
    if (id is! String || !id.startsWith(kDeliveryIdPrefix)) return null;
    if (startedAt is! num) return null;
    return AgentDelivery(
      id: id,
      title: row['title'] is String ? row['title'] as String : null,
      startedAt: startedAt.toDouble(),
      // A row without a count is not known to be unfinished.
      messageCount: row['message_count'] is num
          ? (row['message_count'] as num).toInt()
          : 1,
      unread: row['unread'] == true,
    );
  }
}

/// One request's worth of the session list, judged by the rows the server
/// listed: other chats share the source and pinned rows are appended to every
/// page, so the deliveries alone say nothing about where the page ends.
class DeliveryPage {
  const DeliveryPage(
    this.deliveries, {
    required this.full,
    required this.oldestStartedAt,
  });

  /// Every delivery among the rows, the pinned rows appended behind the
  /// window included.
  final List<AgentDelivery> deliveries;

  /// Whether the list goes on after this page.
  final bool full;

  /// The start time of the last row of the window itself, null for a page
  /// that is not full.
  final double? oldestStartedAt;
}
