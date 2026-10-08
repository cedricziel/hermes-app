import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';
import 'package:hermes_app/src/widgets/grouped_choice_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:hermes_app/src/widgets/settings_search_field.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode settingsChromeNode() => WidgetbookFolder(
  name: 'Settings pages',
  children: [
    WidgetbookComponent(
      name: 'SettingsScaffold',
      useCases: [
        ...onEachPlatform(
          'Tabs, search and add',
          (_) => const _Pushed(_TabsPage()),
        ),
        ...onEachPlatform(
          'List with add menu',
          (_) => const _Pushed(_ListPage()),
        ),
        ...onEachPlatform('Loading', (_) => const _Pushed(_LoadingPage())),
      ],
    ),
    WidgetbookComponent(
      name: 'GroupedSection',
      useCases: [
        ...onEachPlatform(
          'Status and chevrons',
          (context) => _list(_statusSections(context)),
        ),
        ...onEachPlatform('Switches', (_) => _list(_switchSections())),
        ...onEachPlatform(
          'Meta, warning and selection',
          (_) => _list(_metaSection()),
        ),
        ...onEachPlatform(
          'Tiles, captions and errors',
          (context) => _list(_tileSections(context)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'GroupedChoiceRow',
      useCases: [
        ...onEachPlatform(
          'Short options',
          (_) => _list(const [_ThemeChoice()]),
        ),
        ...onEachPlatform(
          'Subtitles, status and disabled',
          (_) => _list(const [_ProviderChoice()]),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SettingsSearchField',
      useCases: [
        ...onEachPlatform('Empty', (_) => _searchField(query: '')),
        ...onEachPlatform('Query', (_) => _searchField(query: 'calendar')),
        ...onEachPlatform(
          'Filter in use',
          (_) => _searchField(query: '', filterActive: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'PillSegmentedControl',
      useCases: [
        WidgetbookUseCase(
          name: 'Three segments',
          builder: (_) => frame(const _Pill(), maxWidth: 360),
        ),
      ],
    ),
  ],
);

Widget _list(List<Widget> sections) =>
    Scaffold(body: GroupedListView(children: sections));

Widget _searchField({required String query, bool filterActive = false}) =>
    frame(_SearchHost(query: query, filterActive: filterActive), maxWidth: 360);

List<Widget> _statusSections(BuildContext context) => [
  GroupedSection(
    header: 'Connected',
    dividerIndent: GroupedMetrics.of(context).indentAfterLeading,
    footer: 'Hermes answers in these chats as this profile.',
    children: [
      GroupedRow(
        title: 'Telegram',
        subtitle: '@orbit_helper_bot',
        value: 'Connected',
        leading: const AppIcon(AppIcons.chat),
        onTap: () {},
      ),
      GroupedRow(
        title: 'Discord',
        subtitle: 'Garden club server',
        value: 'Paused',
        leading: const AppIcon(AppIcons.chat),
        onTap: () {},
      ),
    ],
  ),
  GroupedSection(
    header: 'Available',
    children: [
      GroupedRow(title: 'Slack', value: 'Set up', onTap: () {}),
      GroupedRow(title: 'Signal', value: 'Set up', onTap: () {}),
      GroupedRow(title: 'Matrix', value: 'Set up', onTap: () {}),
    ],
  ),
];

List<Widget> _tileSections(BuildContext context) => [
  GroupedSection(
    dividerIndent: GroupedMetrics.of(context).indentAfterTile,
    footer:
        'Changes apply from the next chat, not to one that is already running.',
    children: [
      GroupedSwitchRow(
        title: 'grafana',
        subtitle: 'https://mcp.grafana.com/mcp',
        caption: 'Remote · OAuth · 2 tools',
        leading: const GroupedTile(child: Text('G')),
        value: true,
        onChanged: (_) {},
      ),
      GroupedSwitchRow(
        title: 'asana',
        subtitle: 'https://mcp.asana.com/sse',
        warning: 'Sign in needed',
        leading: const GroupedTile(child: Text('A')),
        value: true,
        onChanged: (_) {},
      ),
      GroupedSwitchRow(
        title: 'filesystem',
        subtitle: 'npx -y @modelcontextprotocol/server-filesystem',
        monospaceSubtitle: true,
        caption: 'Command · Off',
        leading: const GroupedTile(child: Text('F')),
        value: false,
        onChanged: (_) {},
      ),
      GroupedSwitchRow(
        title: 'Slack',
        error: 'Invalid bot token',
        leading: const GroupedTile(child: AppIcon(AppIcons.chat)),
        value: true,
        onChanged: (_) {},
      ),
    ],
  ),
];

List<Widget> _switchSections() => [
  _Toggles(),
  GroupedSection(
    header: 'Danger zone',
    children: [
      GroupedRow(title: 'Remove plugin', destructive: true, onTap: () {}),
    ],
  ),
];

List<Widget> _metaSection() => [
  GroupedSection(
    header: 'Installed',
    children: [
      GroupedRow(
        title: 'kanban',
        meta: 'v1.4.2',
        subtitle: 'A shared board for tasks the agent works through',
        value: 'On',
        selected: true,
        onTap: () {},
      ),
      GroupedRow(
        title: 'weather-lookup',
        meta: 'v0.3.0',
        subtitle: 'Forecasts for a city, from a public weather service',
        warning: 'Needs a newer Hermes than the one connected',
        value: 'Off',
        onTap: () {},
      ),
      GroupedRow(
        title: 'A plugin with a name long enough to run out of room',
        meta: 'v12.0.0-beta.7',
        subtitle:
            'Its description is long too, so it has to end in an ellipsis '
            'instead of wrapping onto a second line',
        value: 'On',
        onTap: () {},
      ),
    ],
  ),
];

class _Toggles extends StatefulWidget {
  @override
  State<_Toggles> createState() => _TogglesState();
}

class _TogglesState extends State<_Toggles> {
  final _on = {'Memory': true, 'Web search': false};

  @override
  Widget build(BuildContext context) => GroupedSection(
    header: 'Tools',
    footer: 'Changes apply to new chats.',
    children: [
      for (final MapEntry(key: name, value: on) in _on.entries)
        GroupedSwitchRow(
          title: name,
          subtitle: on ? 'Used when it helps' : 'Never used',
          value: on,
          onChanged: (value) => setState(() => _on[name] = value),
        ),
      GroupedSwitchRow(
        title: 'Code execution',
        subtitle: 'Turned off on this server',
        value: false,
        onChanged: null,
      ),
    ],
  );
}

class _SearchHost extends StatefulWidget {
  const _SearchHost({required this.query, required this.filterActive});

  final String query;
  final bool filterActive;

  @override
  State<_SearchHost> createState() => _SearchHostState();
}

class _SearchHostState extends State<_SearchHost> {
  late var _query = widget.query;
  late var _filter = widget.filterActive ? 1 : 0;

  @override
  Widget build(BuildContext context) => SettingsSearchField(
    search: SettingsSearch(
      query: _query,
      hint: 'Search skills',
      onChanged: (q) => setState(() => _query = q),
      filters: [
        for (final (i, label) in ['All', 'Enabled', 'Disabled'].indexed)
          SettingsFilter(
            label: label,
            selected: _filter == i,
            onSelected: () => setState(() => _filter = i),
          ),
      ],
    ),
  );
}

class _Pill extends StatefulWidget {
  const _Pill();

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  var _value = 0;

  @override
  Widget build(BuildContext context) => PillSegmentedControl<int>(
    value: _value,
    segments: const {0: 'Installed', 1: 'Catalog', 2: 'Providers'},
    onChanged: (v) => setState(() => _value = v),
  );
}

/// Shows [page] pushed over another route, so it has a back button.
class _Pushed extends StatelessWidget {
  const _Pushed(this.page);

  final Widget page;

  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateInitialRoutes: (_, _) => [
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Chat'))),
      ),
      MaterialPageRoute<void>(builder: (_) => page),
    ],
  );
}

class _TabsPage extends StatefulWidget {
  const _TabsPage();

  @override
  State<_TabsPage> createState() => _TabsPageState();
}

class _TabsPageState extends State<_TabsPage> {
  var _query = '';

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: SettingsScaffold(
      title: 'Plugins',
      subtitle: 'work · 3 installed',
      tabs: const ['Installed', 'Catalog', 'Providers'],
      search: SettingsSearch(
        query: _query,
        hint: 'Search plugins',
        onChanged: (q) => setState(() => _query = q),
      ),
      actions: [
        SettingsBarAction(
          label: 'Install from Git',
          shortcut: '⌘N',
          icon: AppIcons.add,
          onPressed: () {},
        ),
      ],
      body: TabBarView(
        children: [
          GroupedListView(children: _metaSection()),
          GroupedListView(children: _statusSections(context)),
          GroupedListView(children: _switchSections()),
        ],
      ),
    ),
  );
}

class _ListPage extends StatelessWidget {
  const _ListPage();

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'MCP servers',
    subtitle: 'work · 2 servers',
    actions: [
      SettingsBarAction.menu(
        label: 'Add server',
        icon: AppIcons.add,
        menu: (_) => [
          AdaptiveMenuItem<void>(
            onTap: () {},
            child: const Text('Browse the catalog'),
          ),
          AdaptiveMenuItem<void>(
            onTap: () {},
            child: const Text('Add a custom server'),
          ),
        ],
      ),
      SettingsBarAction.menu(
        label: 'More',
        icon: AppIcons.more,
        menu: (_) => [
          AdaptiveMenuItem<void>(
            onTap: () {},
            child: const Text('Edit as JSON'),
          ),
        ],
      ),
    ],
    body: GroupedListView(children: _statusSections(context)),
  );
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) => const SettingsScaffold(
    title: 'Helper models',
    body: Center(child: CircularProgressIndicator.adaptive()),
  );
}

class _ThemeChoice extends StatefulWidget {
  const _ThemeChoice();

  @override
  State<_ThemeChoice> createState() => _ThemeChoiceState();
}

class _ThemeChoiceState extends State<_ThemeChoice> {
  var _mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) => RadioGroup<ThemeMode>(
    groupValue: _mode,
    onChanged: (mode) => setState(() => _mode = mode!),
    child: GroupedSection(
      header: 'Theme',
      dividerIndent: GroupedChoiceRow.dividerIndent(context),
      children: const [
        GroupedChoiceRow(value: ThemeMode.system, title: 'System'),
        GroupedChoiceRow(value: ThemeMode.light, title: 'Light'),
        GroupedChoiceRow(value: ThemeMode.dark, title: 'Dark'),
      ],
    ),
  );
}

class _ProviderChoice extends StatefulWidget {
  const _ProviderChoice();

  @override
  State<_ProviderChoice> createState() => _ProviderChoiceState();
}

class _ProviderChoiceState extends State<_ProviderChoice> {
  var _provider = 'honcho';

  @override
  Widget build(BuildContext context) => RadioGroup<String>(
    groupValue: _provider,
    onChanged: (provider) => setState(() => _provider = provider!),
    child: GroupedSection(
      header: 'Memory provider',
      footer: 'Where the agent keeps long-term memory.',
      dividerIndent: GroupedChoiceRow.dividerIndent(context),
      children: const [
        GroupedChoiceRow(
          value: '',
          title: 'Built-in',
          subtitle: 'No external memory',
        ),
        GroupedChoiceRow(
          value: 'honcho',
          title: 'honcho',
          meta: 'Ready',
          subtitle: 'Dialectic user modelling across sessions',
        ),
        GroupedChoiceRow(
          value: 'mem0',
          title: 'mem0',
          warning: 'Needs setup',
          subtitle: 'Hosted memory layer',
          enabled: false,
        ),
      ],
    ),
  );
}
