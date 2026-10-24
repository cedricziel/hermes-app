import 'dart:math';

import 'agent_delivery.dart';

/// What one profile's listing of deliveries holds.
class DeliveryListing {
  const DeliveryListing(this.deliveries, {this.capped = false});

  final List<AgentDelivery> deliveries;

  /// The look stopped at its page limit with newer deliveries unread.
  final bool capped;
}

/// Reads pages of deliveries with [page] (by offset), newest first, until
/// one is the last, reaches [since], the record of the profile (null when
/// there is none, which needs only the newest page), or [kDeliveryPages] were
/// read. A page that fails fails the listing.
Future<DeliveryListing> listDeliveries(
  Future<DeliveryPage> Function(int offset) page, {
  required double? since,
}) async {
  final rows = <AgentDelivery>[];
  for (var index = 0; index < kDeliveryPages; index++) {
    final fetched = await page(index * kDeliveryPageSize);
    rows.addAll(fetched.deliveries);
    final oldest = fetched.oldestStartedAt;
    if (since == null || !fetched.full || oldest == null || oldest <= since) {
      return DeliveryListing(rows);
    }
  }
  return DeliveryListing(rows, capped: true);
}

/// How long a delivery may stay without a message before it is given up on:
/// one the plugin never finished writing must not hold the record for good.
const kUnfinishedGrace = 3600.0;

/// A delivery to announce, and the profile it came from.
class FoundMessage {
  const FoundMessage(this.profile, this.delivery);

  final String profile;
  final AgentDelivery delivery;

  /// What the message's text is looked up by.
  ({String profile, String id}) get key => (profile: profile, id: delivery.id);
}

class MessagesFound {
  const MessagesFound({
    required this.record,
    required this.messages,
    required this.capped,
  });

  /// What to store for the next look: per profile name, the start time in
  /// seconds of the newest delivery already dealt with, 0 for none yet.
  final Map<String, double> record;
  final List<FoundMessage> messages;
  final bool capped;
}

/// Compares what [listings] hold with [record] (null when none is stored for
/// this account) for each of [profileNames], the names the server lists now.
/// A profile that is not in [record] is seen for the first time: it only
/// records. A profile whose listing is null or missing failed and keeps its
/// value.
///
/// A delivery is found when it is newer than the profile's record, unread and
/// holds a message. The record moves up to the newest delivery that is older
/// than every delivery still without a message, never backwards: such a
/// delivery is judged again at the next look, and so is any delivery newer
/// than it, so that none is announced twice. Only a delivery newer than the
/// record counts as unfinished, none on a first look, and none that stays so
/// for [kUnfinishedGrace] behind the newest listed.
MessagesFound findMessages({
  required Map<String, double>? record,
  required Map<String, DeliveryListing?> listings,
  required List<String> profileNames,
}) {
  final next = <String, double>{};
  final messages = <FoundMessage>[];
  var capped = false;
  for (final name in profileNames) {
    final before = record?[name];
    final listing = listings[name];
    if (listing == null) {
      if (before != null) next[name] = before;
      continue;
    }
    capped |= listing.capped;
    final rows = {for (final row in listing.deliveries) row.id: row}.values;
    final newest = rows.fold<double>(0, (a, row) => max(a, row.startedAt));
    final unfinished = before == null
        ? null
        : rows
              .where(
                (row) =>
                    row.messageCount == 0 &&
                    row.startedAt > before &&
                    newest - row.startedAt <= kUnfinishedGrace,
              )
              .map((row) => row.startedAt)
              .fold<double?>(null, (a, b) => a == null || b < a ? b : a);
    final settled = [
      for (final row in rows)
        if (unfinished == null || row.startedAt < unfinished) row,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final cutoff = settled.isEmpty ? 0.0 : settled.first.startedAt;
    if (before == null) {
      next[name] = cutoff;
      continue;
    }
    next[name] = cutoff > before ? cutoff : before;
    for (final row in settled) {
      if (row.startedAt > before && row.unread && row.messageCount > 0) {
        messages.add(FoundMessage(name, row));
      }
    }
  }
  return MessagesFound(record: next, messages: messages, capped: capped);
}
