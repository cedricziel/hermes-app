import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/widgets/chat_branch_notice.dart';
import 'package:hermes_app/src/chat/widgets/mac_search_results.dart';
import 'package:hermes_app/src/chat/widgets/mac_thread_row.dart';
import 'package:hermes_app/src/chat/widgets/thread_actions_menu.dart';
import 'package:hermes_app/src/chat/widgets/thread_search_view.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';
import 'mac_sidebar_use_cases.dart' show mac;

const _title = 'Release notes for the spring update';
const _long =
    'Compare the backup providers for the photo library, the notes folder and '
    'the old laptop, and pick one that works offline';

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Widget _german(Widget child) => Builder(
  builder: (context) => Localizations.override(
    context: context,
    locale: const Locale('de'),
    child: child,
  ),
);

Widget _notice(ChatBranchNoticeState state, {String? title = _title}) => frame(
  ChatBranchNotice(state: state, parentTitle: title, onTap: () {}),
  maxWidth: 560,
);

WidgetbookUseCase _case(String name, Widget Function() build) =>
    WidgetbookUseCase(name: name, builder: (_) => build());

final _thread = ChatThread(
  id: 'branch-1',
  title: 'Try the other approach',
  updatedAt: DateTime(2026, 11, 20),
  remote: true,
);

final _hit = ThreadSearchHit(
  id: 'branch-1',
  title: 'Try the other approach',
  snippet: const [
    (text: 'Same plan, but with the ', match: false),
    (text: 'backup', match: true),
    (text: ' job first.', match: false),
  ],
  updatedAt: DateTime(2026, 11, 20),
  branch: true,
);

Widget _touchRow({required bool branch, bool selected = false}) => frame(
  SidebarThreadRow(
    thread: _thread,
    selected: selected,
    busy: false,
    onTap: () {},
    branch: branch,
  ),
  maxWidth: 300,
);

Widget _macRow({required bool branch, bool selected = false}) => mac(
  frame(
    MacThreadRow(
      title: _thread.title,
      selected: selected,
      onTap: () {},
      menuItems: (context) => const <PopupMenuEntry<ThreadAction>>[],
      onAction: (_) {},
      branch: branch,
    ),
    maxWidth: 260,
  ),
);

WidgetbookNode chatBranchNode() => WidgetbookFolder(
  name: 'Branched chat',
  children: [
    WidgetbookComponent(
      name: 'ChatBranchNotice',
      useCases: [
        _case('Title known', () => _notice(ChatBranchNoticeState.title)),
        _case(
          'Title not loaded',
          () => _notice(ChatBranchNoticeState.unknown, title: null),
        ),
        _case('Opening', () => _notice(ChatBranchNoticeState.opening)),
        _case('Deleted', () => _notice(ChatBranchNoticeState.deleted)),
        _case(
          'Could not reach Hermes',
          () => _notice(ChatBranchNoticeState.unreachable),
        ),
        _case(
          'Long title wraps to two lines',
          () => _notice(ChatBranchNoticeState.title, title: _long),
        ),
        ...onEachPlatform(
          'Title known',
          (_) => _notice(ChatBranchNoticeState.title),
        ),
        ...onEachPlatform(
          'Could not reach Hermes',
          (_) => _notice(ChatBranchNoticeState.unreachable),
        ),
        _case(
          'German, title known',
          () => _german(_notice(ChatBranchNoticeState.title)),
        ),
        _case(
          'German, could not reach Hermes',
          () => _german(_notice(ChatBranchNoticeState.unreachable)),
        ),
        _case(
          'Largest text (3x), title known',
          () => _scaled(3, _notice(ChatBranchNoticeState.title, title: _long)),
        ),
        _case(
          'Largest text (3x), could not reach Hermes',
          () => _scaled(3, _notice(ChatBranchNoticeState.unreachable)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SidebarThreadRow',
      useCases: [
        _case('Plain', () => _touchRow(branch: false)),
        _case('Branch', () => _touchRow(branch: true)),
        _case(
          'Branch, selected',
          () => _touchRow(branch: true, selected: true),
        ),
        _case(
          'Branch, largest text (3x)',
          () => _scaled(3, _touchRow(branch: true)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'MacThreadRow',
      useCases: [
        _case('Plain', () => _macRow(branch: false)),
        _case('Branch', () => _macRow(branch: true)),
        _case('Branch, selected', () => _macRow(branch: true, selected: true)),
      ],
    ),
    WidgetbookComponent(
      name: 'ThreadSearchResults',
      useCases: [
        _case(
          'Branch among results',
          () => fill(
            ThreadSearchResults(
              query: 'backup',
              status: ThreadSearchStatus.done,
              hits: [
                _hit,
                ThreadSearchHit(
                  id: 'plain-1',
                  title: 'Nightly backup to the NAS',
                  snippet: const [],
                  updatedAt: DateTime(2026, 10, 1),
                ),
              ],
              onOpen: (_) {},
            ),
            width: 300,
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'MacSearchResults',
      useCases: [
        _case(
          'Branch among results',
          () => mac(
            fill(
              MacSearchResults(
                query: 'backup',
                status: ThreadSearchStatus.done,
                hits: [
                  _hit,
                  ThreadSearchHit(
                    id: 'plain-1',
                    title: 'Nightly backup to the NAS',
                    snippet: const [],
                    updatedAt: DateTime(2026, 10, 1),
                  ),
                ],
                scope: ThreadSearchScope.profile,
                recent: const [],
                onOpen: (_) {},
                onPickRecent: (_) {},
              ),
              width: 260,
            ),
          ),
        ),
      ],
    ),
  ],
);
