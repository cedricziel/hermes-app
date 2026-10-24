import 'dart:async';
import 'dart:math';

import '../chat/hermes_chat_repository.dart';
import '../profiles/hermes_profiles_repository.dart';
import 'find_messages.dart';

/// Lists the deliveries of each of [names] and compares them with [record]
/// (see [findMessages]). A profile whose listing fails or takes longer than
/// [lookup] stands for one that could not be read, and [onFailure] hears the
/// error. Shared by the app in front and the background run.
Future<MessagesFound> lookForMessages({
  required HermesChatRepository chat,
  required List<String> names,
  required Map<String, double>? record,
  required DateTime Function() clock,
  required Duration lookup,
  required void Function(Object error) onFailure,
}) async {
  Future<DeliveryListing?> list(String name) async {
    try {
      return await listDeliveries(
        (offset) => chat.loadDeliveries(profile: name, offset: offset),
        since: record?[name],
      ).timeout(lookup);
    } on Object catch (error) {
      onFailure(error);
      return null;
    }
  }

  final listings = await Future.wait([for (final name in names) list(name)]);
  // The device's clock may be wrong, but no chat started after the newest one
  // the server lists.
  final newestListed = listings
      .whereType<DeliveryListing>()
      .expand((listing) => listing.listed)
      .fold<double>(0, max);
  return findMessages(
    record: record,
    listings: {for (var i = 0; i < names.length; i++) names[i]: listings[i]},
    profileNames: names,
    now: max(clock().millisecondsSinceEpoch / 1000, newestListed),
  );
}

/// The text of each message in [found], by [FoundMessage.key], read in
/// parallel; one that cannot be read within [lookup] is left out.
Future<Map<({String profile, String id}), String>> readMessageTexts(
  HermesChatRepository chat,
  MessagesFound found,
  Duration lookup,
) async {
  Future<String?> text(FoundMessage message) async {
    try {
      final page = await chat
          .loadMessagePage(
            message.delivery.id,
            profile: message.profile,
            limit: 1,
          )
          .timeout(lookup);
      return page.messages.firstOrNull?.content;
    } on Object {
      return null;
    }
  }

  final texts = await Future.wait([
    for (final message in found.messages) text(message),
  ]);
  return {
    for (var i = 0; i < texts.length; i++) found.messages[i].key: ?texts[i],
  };
}

/// The server's active profile, for a message of another one to say which when
/// the chat screen has not reported the profile it shows. Null when it cannot
/// be read within [lookup].
Future<String?> activeProfileName(
  HermesProfilesRepository profiles,
  Duration lookup,
) async {
  try {
    final active = (await profiles.loadActive().timeout(lookup)).active;
    return active.isEmpty ? null : active;
  } on Object {
    return null;
  }
}
