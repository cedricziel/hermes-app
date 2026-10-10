import 'package:flutter/foundation.dart';

import '../../chat/chat_controller.dart';
import '../../chat/chat_models.dart';
import '../../chat/widgets/approval_card.dart';

/// What the menu bar icon shows.
enum MenuBarIconState { idle, working, attention }

/// A chat that is replying.
@immutable
class MenuBarReply {
  const MenuBarReply({
    required this.threadId,
    required this.profile,
    required this.title,
  });

  final String threadId;
  final String? profile;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is MenuBarReply &&
      other.threadId == threadId &&
      other.profile == profile &&
      other.title == title;

  @override
  int get hashCode => Object.hash(threadId, profile, title);
}

enum MenuBarRequestKind {
  /// The agent wants to run something; the menu can answer it.
  approval,

  /// A question, a vault prompt or a secret: only the chat can answer.
  needsYou,
}

/// A request a followed chat is waiting on.
@immutable
class MenuBarRequest {
  const MenuBarRequest({
    required this.threadId,
    required this.profile,
    required this.threadTitle,
    required this.requestId,
    required this.kind,
    this.command = '',
    this.choices = const [],
  });

  final String threadId;
  final String? profile;
  final String threadTitle;
  final String requestId;
  final MenuBarRequestKind kind;

  /// What an approval would run, or what it is about when it has no command.
  final String command;

  /// The choices an approval offers, exactly as its card does.
  final List<String> choices;

  @override
  bool operator ==(Object other) =>
      other is MenuBarRequest &&
      other.threadId == threadId &&
      other.profile == profile &&
      other.threadTitle == threadTitle &&
      other.requestId == requestId &&
      other.kind == kind &&
      other.command == command &&
      listEquals(other.choices, choices);

  @override
  int get hashCode => Object.hash(
    threadId,
    profile,
    threadTitle,
    requestId,
    kind,
    command,
    Object.hashAll(choices),
  );
}

/// The replies and requests of the chats this app follows, as the menu bar
/// item shows them. Two models are equal when the menu would look the same,
/// so a caller rebuilds the menu only when they differ.
@immutable
class MenuBarExtraModel {
  const MenuBarExtraModel({this.replies = const [], this.requests = const []});

  /// Signed out, or nothing to show.
  static const empty = MenuBarExtraModel();

  /// Reads the loaded threads of [chat], which is null while signed out. Only
  /// state the chat already holds is used, so this makes no request.
  factory MenuBarExtraModel.of(ChatController? chat) {
    if (chat == null) return empty;
    final replies = <MenuBarReply>[];
    final requests = <MenuBarRequest>[];
    for (final thread in chat.threads) {
      if (thread.isReplying) {
        replies.add(
          MenuBarReply(
            threadId: thread.id,
            profile: chat.profile,
            title: thread.title,
          ),
        );
      }
      for (final message in thread.messages) {
        for (final request in message.inputRequests) {
          if (request.status != InputRequestStatus.pending) continue;
          requests.add(_requestOf(request, thread, chat.profile));
        }
      }
    }
    return MenuBarExtraModel(replies: replies, requests: requests);
  }

  static MenuBarRequest _requestOf(
    InputRequest request,
    ChatThread thread,
    String? profile,
  ) {
    if (request is ApprovalRequest) {
      return MenuBarRequest(
        threadId: thread.id,
        profile: profile,
        threadTitle: thread.title,
        requestId: request.requestId,
        kind: MenuBarRequestKind.approval,
        command: request.command.isNotEmpty
            ? request.command
            : request.description,
        choices: offeredApprovalChoices(request),
      );
    }
    return MenuBarRequest(
      threadId: thread.id,
      profile: profile,
      threadTitle: thread.title,
      requestId: request.requestId,
      kind: MenuBarRequestKind.needsYou,
    );
  }

  final List<MenuBarReply> replies;
  final List<MenuBarRequest> requests;

  MenuBarIconState get state => requests.isNotEmpty
      ? MenuBarIconState.attention
      : replies.isNotEmpty
      ? MenuBarIconState.working
      : MenuBarIconState.idle;

  int get approvals =>
      requests.where((r) => r.kind == MenuBarRequestKind.approval).length;

  @override
  bool operator ==(Object other) =>
      other is MenuBarExtraModel &&
      listEquals(other.replies, replies) &&
      listEquals(other.requests, requests);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(replies), Object.hashAll(requests));
}
