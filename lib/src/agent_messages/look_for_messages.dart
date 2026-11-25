import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../chat/hermes_chat_repository.dart';
import '../profiles/hermes_profiles_repository.dart';
import 'find_messages.dart';

/// Runs [read] with its own [CancelToken] and gives up on it after [lookup],
/// or as soon as [stop] is cancelled. A request that is given up on is closed
/// here, so it does not hold a socket and a span until its receive timeout.
Future<T> readWithin<T>(
  Duration lookup,
  CancelToken? stop,
  Future<T> Function(CancelToken token) read,
) async {
  final own = CancelToken();
  unawaited(
    stop?.whenCancel.then((cancel) {
      if (!own.isCancelled) own.cancel(cancel.error);
    }),
  );
  try {
    return await read(own).timeout(lookup);
  } on TimeoutException {
    if (!own.isCancelled) own.cancel('lookup timeout');
    rethrow;
  }
}

/// Lists the deliveries of each of [names] and compares them with [record]
/// (see [findMessages]). A profile whose listing fails or takes longer than
/// [lookup] stands for one that could not be read, and [onFailure] hears the
/// error. Shared by the app in front and the background run.
///
/// A listing that takes longer than [lookup] is closed, and [stop] closes
/// every request in flight, so that none outlives the look to time out later
/// beside the requests of the next one.
Future<MessagesFound> lookForMessages({
  required HermesChatRepository chat,
  required List<String> names,
  required Map<String, double>? record,
  required DateTime Function() clock,
  required Duration lookup,
  required void Function(Object error) onFailure,
  CancelToken? stop,
}) async {
  Future<DeliveryListing?> list(String name) async {
    try {
      return await readWithin(
        lookup,
        stop,
        (token) => listDeliveries(
          (offset) => chat.loadDeliveries(
            profile: name,
            offset: offset,
            cancelToken: token,
          ),
          since: record?[name],
        ),
      );
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
  Duration lookup, {
  CancelToken? stop,
}) async {
  Future<String?> text(FoundMessage message) async {
    try {
      final page = await readWithin(
        lookup,
        stop,
        (token) => chat.loadMessagePage(
          message.delivery.id,
          profile: message.profile,
          limit: 1,
          cancelToken: token,
        ),
      );
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

/// The launch profile, for a message of another one to say which when the
/// chat screen has not reported the profile it shows. Null when it cannot be
/// read within [lookup].
Future<String?> activeProfileName(
  HermesProfilesRepository profiles,
  Duration lookup,
) async {
  try {
    return await profiles.resolver.load().timeout(lookup);
  } on Object {
    return null;
  }
}
