/// The notification categories and actions that let the user answer an
/// approval or a question without opening the app (iOS and macOS, mirrored
/// to the watch), and how an action turns back into an answer.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../chat/chat_models.dart';
import '../chat/chat_transport.dart';
import 'attention_policy.dart';

const kApprovalCategoryPrefix = 'hermes.request.approval';

/// Reply and Open, for an open-ended or a multi-select question. A question
/// with choices gets a category of its own under this prefix.
const kQuestionCategory = 'hermes.request.question';

const kAllowOnceAction = 'hermes.action.allow-once';
const kAllowSessionAction = 'hermes.action.allow-session';
const kAllowAlwaysAction = 'hermes.action.allow-always';
const kDenyAction = 'hermes.action.deny';

/// Followed by the index of the choice among the buttons.
const kChoiceActionPrefix = 'hermes.action.choice.';
const kOtherAction = 'hermes.action.other';
const kReplyAction = 'hermes.action.reply';
const kOpenAction = 'hermes.action.open';

/// The most choice buttons a question notification shows. Above it the
/// first three and Other… are shown.
const kMaxChoiceActions = 4;

/// Approval choices in the order the buttons show them, with each one's
/// action and title.
const _approvalActions = [
  ('once', kAllowOnceAction, 'Allow once'),
  ('session', kAllowSessionAction, 'Allow for session'),
  ('always', kAllowAlwaysAction, 'Always allow'),
  ('deny', kDenyAction, 'Deny'),
];

/// One button of a request notification. Every one needs the device
/// unlocked.
class RequestAction {
  const RequestAction(
    this.id,
    this.title, {
    this.destructive = false,
    this.foreground = false,
    this.textInput = false,
  });

  final String id;
  final String title;
  final bool destructive;

  /// Opens the app instead of answering in the background.
  final bool foreground;

  /// Asks for text, sent with [kReplyButton].
  final bool textInput;

  static const kReplyButton = 'Send';
  static const kReplyPlaceholder = 'Your answer';

  Set<DarwinNotificationActionOption> get _options => {
    DarwinNotificationActionOption.authenticationRequired,
    if (destructive) DarwinNotificationActionOption.destructive,
    if (foreground) DarwinNotificationActionOption.foreground,
  };

  DarwinNotificationAction toDarwin() => textInput
      ? DarwinNotificationAction.text(
          id,
          title,
          buttonTitle: kReplyButton,
          placeholder: kReplyPlaceholder,
          options: _options,
        )
      : DarwinNotificationAction.plain(id, title, options: _options);

  Map<String, Object?> toChannel() => {
    'id': id,
    'title': title,
    'options': _options.fold<int>(0, (all, option) => all | option.value),
    if (textInput) 'buttonTitle': kReplyButton,
    if (textInput) 'placeholder': kReplyPlaceholder,
  };
}

/// A notification category: its buttons and what the system shows in place
/// of the body while previews are hidden.
class RequestCategory {
  const RequestCategory(
    this.id, {
    required this.placeholder,
    this.actions = const [],
  });

  final String id;
  final String placeholder;
  final List<RequestAction> actions;

  /// Registered when it is first used rather than at start.
  bool get isDynamic => id.startsWith('$kQuestionCategory.');

  DarwinNotificationCategory toDarwin() => DarwinNotificationCategory(
    id,
    actions: [for (final action in actions) action.toDarwin()],
  );

  Map<String, Object?> toChannel() => {
    'id': id,
    'placeholder': placeholder,
    'actions': [for (final action in actions) action.toChannel()],
  };
}

const _reply = RequestAction(kReplyAction, 'Reply', textInput: true);
const _open = RequestAction(kOpenAction, 'Open', foreground: true);

const _openEnded = RequestCategory(
  kQuestionCategory,
  placeholder: kQuestionBody,
  actions: [_reply, _open],
);

RequestCategory _approvalCategory(List<String> offered) => RequestCategory(
  '$kApprovalCategoryPrefix.${offered.join('-')}',
  placeholder: kApprovalBody,
  actions: [
    for (final (choice, id, title) in _approvalActions)
      if (offered.contains(choice))
        RequestAction(
          id,
          title,
          destructive: choice == 'always' || choice == 'deny',
        ),
  ],
);

/// The categories registered at start: one per combination of approval
/// choices, and the open-ended question's.
List<RequestCategory> staticRequestCategories() {
  final choices = [for (final (choice, _, _) in _approvalActions) choice];
  return [
    for (var mask = 1; mask < 1 << choices.length; mask++)
      _approvalCategory([
        for (var i = 0; i < choices.length; i++)
          if (mask & (1 << i) != 0) choices[i],
      ]),
    _openEnded,
  ];
}

/// The category a notification for [request] is posted under, or null when
/// it gets no buttons: a request with several questions, or one the app
/// cannot answer.
RequestCategory? requestCategoryFor(InputRequest request) {
  switch (request) {
    case ApprovalRequest(:final choices):
      final offered = [
        for (final (choice, _, _) in _approvalActions)
          if (choices.contains(choice)) choice,
      ];
      return offered.isEmpty ? null : _approvalCategory(offered);
    case ClarifyRequest(questions: [final question]):
      if (question.multiSelect || question.choices.isEmpty) return _openEnded;
      final buttons = _choiceButtons(question.choices);
      final more = question.choices.length > buttons.length;
      return RequestCategory(
        '$kQuestionCategory.${_hash(buttons)}',
        placeholder: kQuestionBody,
        actions: [
          for (final (index, choice) in buttons.indexed)
            RequestAction('$kChoiceActionPrefix$index', choice),
          if (more)
            const RequestAction(kOtherAction, 'Other…', foreground: true),
          _reply,
        ],
      );
    default:
      return null;
  }
}

List<String> _choiceButtons(List<String> choices) =>
    choices.length <= kMaxChoiceActions
    ? choices
    : choices.take(kMaxChoiceActions - 1).toList();

/// FNV-1a over the button titles, so two questions with the same buttons
/// share a category.
String _hash(List<String> titles) {
  var hash = 0x811c9dc5;
  for (final unit in titles.join('\u0000').codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

enum PendingRequestKind { approval, question }

/// What a request notification carries so that an action can be answered
/// without the app's state: the request, and for a question the buttons it
/// showed.
class PendingRequest {
  const PendingRequest({
    required this.requestId,
    required this.kind,
    this.questionId = '',
    this.multiSelect = false,
    this.choices = const [],
  });

  final String requestId;
  final PendingRequestKind kind;
  final String questionId;
  final bool multiSelect;

  /// The choice titles shown as buttons, in order.
  final List<String> choices;

  Map<String, Object?> toJson() => {
    'i': requestId,
    'k': kind.name,
    if (questionId.isNotEmpty) 'q': questionId,
    if (multiSelect) 'm': true,
    if (choices.isNotEmpty) 'c': choices,
  };

  static PendingRequest? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['i'];
    final kind = PendingRequestKind.values
        .where((kind) => kind.name == json['k'])
        .firstOrNull;
    if (id is! String || id.isEmpty || kind == null) return null;
    final choices = json['c'];
    return PendingRequest(
      requestId: id,
      kind: kind,
      questionId: json['q'] is String ? json['q'] as String : '',
      multiSelect: json['m'] == true,
      choices: choices is List
          ? choices.whereType<String>().toList()
          : const [],
    );
  }
}

/// What a notification for [request] must remember to answer it, or null
/// when it gets no buttons.
PendingRequest? pendingRequestFor(InputRequest request) {
  if (requestCategoryFor(request) == null) return null;
  return switch (request) {
    ApprovalRequest(:final requestId) => PendingRequest(
      requestId: requestId,
      kind: PendingRequestKind.approval,
    ),
    ClarifyRequest(:final requestId, questions: [final question]) =>
      PendingRequest(
        requestId: requestId,
        kind: PendingRequestKind.question,
        questionId: question.qid,
        multiSelect: question.multiSelect,
        choices: question.multiSelect
            ? const []
            : _choiceButtons(question.choices),
      ),
    _ => null,
  };
}

/// The answer the user gave to [request] with [actionId] and, for Reply, the
/// typed [input]. Null when the action answers nothing (Other…, Open) or
/// does not fit the request.
OpenRequestAnswer? answerFor(
  PendingRequest request,
  String actionId,
  String? input,
) {
  switch (request.kind) {
    case PendingRequestKind.approval:
      for (final (choice, id, _) in _approvalActions) {
        if (id == actionId) return ApprovalChoiceAnswer(choice);
      }
      return null;
    case PendingRequestKind.question:
      final String? value;
      if (actionId == kReplyAction) {
        value = input?.trim();
      } else if (actionId.startsWith(kChoiceActionPrefix)) {
        final index = int.tryParse(
          actionId.substring(kChoiceActionPrefix.length),
        );
        value = index != null && index >= 0 && index < request.choices.length
            ? request.choices[index]
            : null;
      } else {
        value = null;
      }
      if (value == null || value.isEmpty) return null;
      return QuestionAnswer(
        questionId: request.questionId,
        values: [value],
        multiSelect: request.multiSelect,
      );
  }
}
