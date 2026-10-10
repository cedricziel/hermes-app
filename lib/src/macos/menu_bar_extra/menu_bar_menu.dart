import '../../chat/widgets/approval_card.dart';
import 'menu_bar_extra_model.dart';

/// What picking an item of the menu bar item's menu does.
sealed class MenuBarAction {
  const MenuBarAction();
}

/// Shows the chat of a reply or of a request only the chat can answer.
class OpenChatAction extends MenuBarAction {
  const OpenChatAction({required this.threadId, required this.profile});

  final String threadId;
  final String? profile;
}

/// Answers an approval with one of the choices it offers.
class AnswerApprovalAction extends MenuBarAction {
  const AnswerApprovalAction(this.request, this.choice);

  final MenuBarRequest request;
  final String choice;
}

class NewChatAction extends MenuBarAction {
  const NewChatAction();
}

class ShowMainWindowAction extends MenuBarAction {
  const ShowMainWindowAction();
}

class QuitAction extends MenuBarAction {
  const QuitAction();
}

/// Brings up the unlock prompt of a locked app.
class UnlockAction extends MenuBarAction {
  const UnlockAction();
}

/// One entry of the menu, as the runner draws it. A [key] makes it pickable;
/// an entry without one is a heading or a note.
class MenuBarItem {
  const MenuBarItem(this.title, {this.key, this.enabled = true, this.children})
    : separator = false;

  const MenuBarItem.separator()
    : title = '',
      key = null,
      enabled = false,
      children = null,
      separator = true;

  final String title;
  final String? key;
  final bool enabled;
  final List<MenuBarItem>? children;
  final bool separator;

  Map<String, Object?> toJson() => {
    'title': title,
    'key': key,
    'enabled': enabled,
    'separator': separator,
    'children': ?children?.map((c) => c.toJson()).toList(),
  };
}

/// The menu for a [MenuBarExtraModel] and what each of its keys does.
class MenuBarMenu {
  const MenuBarMenu(this.items, this.actions);

  final List<MenuBarItem> items;
  final Map<String, MenuBarAction> actions;
}

/// The longest chat title the menu shows.
const kMenuBarTitleLength = 40;

/// The longest command in an approval's row; its submenu shows more.
const kMenuBarCommandLength = 60;

/// The longest command the submenu's first line shows.
const kMenuBarFullCommandLength = 300;

/// Lists the running replies and what waits for the user, then New Chat, Show
/// Main Window and Quit. With nothing running that is all of it.
///
/// Keys come from what a row does, never from its position, so a pick made
/// on a menu that has changed since still means what it said or finds no
/// action. A [locked] app shows counts only, no title or command, and an
/// Unlock entry in place of the rows that act on a chat. A request in
/// [inFlight] (by [MenuBarRequest.key]) is being answered and offers nothing
/// to pick.
MenuBarMenu buildMenuBarMenu(
  MenuBarExtraModel model, {
  bool locked = false,
  Set<String> inFlight = const {},
}) {
  final items = <MenuBarItem>[];
  final actions = <String, MenuBarAction>{};
  MenuBarItem pickable(String key, String title, MenuBarAction action) {
    actions[key] = action;
    return MenuBarItem(title, key: key);
  }

  if (locked) {
    final replies = model.replies.length;
    final requests = model.requests.length;
    if (replies > 0) {
      items.add(
        MenuBarItem(
          replies == 1 ? '1 reply running' : '$replies replies running',
          enabled: false,
        ),
      );
    }
    if (requests > 0) {
      items.add(
        MenuBarItem(
          requests == 1 ? '1 request waiting' : '$requests requests waiting',
          enabled: false,
        ),
      );
    }
    items.add(pickable(kMenuBarUnlock, 'Unlock Hermes…', const UnlockAction()));
  } else {
    if (model.replies.isNotEmpty) {
      items.add(const MenuBarItem('Running replies', enabled: false));
      for (final reply in model.replies) {
        items.add(
          pickable(
            'reply:${reply.threadId}',
            _trimmed(reply.title, kMenuBarTitleLength),
            OpenChatAction(threadId: reply.threadId, profile: reply.profile),
          ),
        );
      }
    }
    if (model.requests.isNotEmpty) {
      if (items.isNotEmpty) items.add(const MenuBarItem.separator());
      items.add(const MenuBarItem('Needs you', enabled: false));
      for (final request in model.requests) {
        switch (request.kind) {
          case MenuBarRequestKind.approval:
            final command = request.command.trim().isEmpty
                ? 'Approval needed'
                : request.command;
            items.add(
              MenuBarItem(
                _trimmed(command, kMenuBarCommandLength),
                children: inFlight.contains(request.key)
                    ? const [MenuBarItem('Answering…', enabled: false)]
                    : [
                        MenuBarItem(
                          '${_trimmed(request.threadTitle, kMenuBarTitleLength)}: '
                          '${_trimmed(command, kMenuBarFullCommandLength)}',
                          enabled: false,
                        ),
                        const MenuBarItem.separator(),
                        for (final choice in request.choices)
                          pickable(
                            'approve:${request.threadId}:${request.requestId}:'
                            '$choice',
                            approvalChoiceLabels[choice] ?? choice,
                            AnswerApprovalAction(request, choice),
                          ),
                      ],
              ),
            );
          case MenuBarRequestKind.needsYou:
            items.add(
              pickable(
                'request:${request.threadId}:${request.requestId}',
                'Open ${_trimmed(request.threadTitle, kMenuBarTitleLength)}',
                OpenChatAction(
                  threadId: request.threadId,
                  profile: request.profile,
                ),
              ),
            );
        }
      }
    }
  }
  if (items.isNotEmpty) items.add(const MenuBarItem.separator());
  items
    ..add(pickable('new', 'New Chat', const NewChatAction()))
    ..add(pickable('show', 'Show Main Window', const ShowMainWindowAction()))
    ..add(const MenuBarItem.separator())
    ..add(pickable('quit', 'Quit Hermes', const QuitAction()));
  return MenuBarMenu(items, actions);
}

/// The key of the Unlock entry.
const kMenuBarUnlock = 'unlock';

final _whitespace = RegExp(r'\s+');

/// [text] on one line, cut to [max] characters with an ellipsis.
String _trimmed(String text, int max) {
  final line = text.trim().replaceAll(_whitespace, ' ');
  return line.length <= max
      ? line
      : '${line.substring(0, max - 1).trimRight()}…';
}
