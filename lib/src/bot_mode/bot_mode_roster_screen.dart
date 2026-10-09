import 'package:flutter/material.dart';

import '../models/hermes_models_repository.dart';
import '../models/model_provider_option.dart';
import '../models/widgets/model_picker.dart';
import '../macos/mac_toolbar.dart' show macToolbarButtonStyle;
import '../plugins/widgets/catalog_row.dart' show InstallButton;
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/named_icon_button.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/settings_search_field.dart';
import '../widgets/state_message.dart';
import 'group_protocol/hermes_groups_repository.dart';
import 'groups/group_rooms_panel.dart';
import 'bot_mode_roster_repository.dart';

/// Server-backed specialist roster. Profile names stay stable; titles are
/// presentation metadata and can be edited independently.
class BotModeRosterScreen extends StatefulWidget {
  const BotModeRosterScreen({
    super.key,
    required this.repository,
    this.models,
    this.onOpen,
    this.groups,
    this.onOpenGroup,
  });

  final BotModeRosterRepository repository;
  final HermesModelsRepository? models;
  final ValueChanged<BotModeBot>? onOpen;
  final HermesGroupsRepository? groups;
  final ValueChanged<GroupRoom>? onOpenGroup;

  @override
  State<BotModeRosterScreen> createState() => _BotModeRosterScreenState();
}

class _BotModeRosterScreenState extends State<BotModeRosterScreen> {
  BotModeRoster? _roster;
  Object? _error;
  bool _loading = true;
  String _query = '';
  final _adding = <String>{};
  final _groupsPanel = GlobalKey<GroupRoomsPanelState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roster = await widget.repository.load();
      if (mounted) {
        setState(() {
          _roster = roster;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _add(BotModeBot profile) async {
    setState(() => _adding.add(profile.name));
    try {
      final result = await widget.repository.save(
        profile,
        title: profile.title,
      );
      if (!result.succeeded) throw StateError('Presentation was not saved');
      await _load();
    } on Object {
      if (mounted) {
        _message('Could not add this profile. Retry from the roster.');
      }
    } finally {
      if (mounted) setState(() => _adding.remove(profile.name));
    }
  }

  Future<void> _refresh() =>
      Future.wait([_load(), ?_groupsPanel.currentState?.refresh()]);

  Future<void> _create() async {
    final name = TextEditingController();
    final title = TextEditingController();
    final description = TextEditingController();
    final soul = TextEditingController();
    var mirror = true;
    String? createdName;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Create bot'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      enabled: createdName == null,
                      decoration: const InputDecoration(
                        labelText: 'Profile name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Bot title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: soul,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Standing instructions',
                      ),
                    ),
                    SwitchListTile(
                      value: mirror,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Copy provider sign-in'),
                      subtitle: const Text(
                        'The server copies credentials to this profile.',
                      ),
                      onChanged: createdName == null
                          ? (value) => update(() => mirror = value)
                          : null,
                    ),
                    if (createdName != null)
                      Text(
                        'Profile $createdName was created. Retry saves its details.',
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final profile = name.text.trim();
                  if (profile.isEmpty) return;
                  try {
                    if (createdName == null) {
                      final created = await widget.repository.create(
                        name: profile,
                        description: description.text,
                        soul: soul.text,
                        mirrorCredentials: mirror,
                      );
                      createdName = created.name;
                    }
                    final roster = await widget.repository.load();
                    final bot = [
                      ...roster.bots,
                      ...roster.availableProfiles,
                    ].where((bot) => bot.name == createdName).first;
                    final saved = await widget.repository.save(
                      bot,
                      title: title.text.trim().isEmpty
                          ? profile
                          : title.text.trim(),
                    );
                    if (!saved.succeeded) {
                      throw StateError('Presentation was not saved');
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    await _load();
                  } on Object {
                    update(() {});
                    if (mounted) {
                      _message(
                        createdName == null
                            ? 'Could not create bot'
                            : 'Bot created; details were not saved. Retry.',
                      );
                    }
                  }
                },
                child: Text(createdName == null ? 'Create' : 'Retry save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      name.dispose();
      title.dispose();
      description.dispose();
      soul.dispose();
    }
  }

  Future<void> _edit(BotModeBot bot) async {
    BotModeDetails details;
    try {
      details = await widget.repository.describe(bot.name);
    } on Object {
      if (mounted) _message('Could not load bot details');
      return;
    }
    if (!mounted) return;
    final title = TextEditingController(text: bot.title);
    final rawSummary = bot.metadata['description'];
    final summary = TextEditingController(
      text: rawSummary is String ? rawSummary : '',
    );
    final description = TextEditingController(text: details.description);
    final soul = TextEditingController(text: details.soul);
    ModelChoice? chosen;
    var currentBot = bot;
    var failed = <String>[];
    var conflict = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Edit ${bot.title}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile: ${bot.name}'),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: summary,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Roster summary',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: soul,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Standing instructions',
                      ),
                    ),
                    if (widget.models != null)
                      TextButton(
                        onPressed: () async {
                          final options = await widget.models!.load(
                            profile: bot.name,
                          );
                          if (!dialogContext.mounted) return;
                          await showModelPicker(
                            dialogContext,
                            options: options,
                            selected: chosen ?? options.current,
                            withEffort: false,
                            title: 'Default model',
                            onChanged: (choice) =>
                                update(() => chosen = choice),
                          );
                        },
                        child: Text(
                          chosen?.modelId ??
                              details.model ??
                              'Choose default model',
                        ),
                      ),
                    if (conflict)
                      const Text(
                        'Another client changed this bot. Your edits are still here.',
                      ),
                    if (failed.isNotEmpty)
                      Text('Not saved: ${failed.join(', ')}'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    var result = await widget.repository.save(
                      currentBot,
                      title: title.text,
                      summary: summary.text,
                      description: description.text,
                      soul: soul.text,
                      model: chosen?.modelId,
                      provider: chosen?.providerId,
                    );
                    final pickedModel = chosen;
                    if (result.confirmRequired &&
                        pickedModel != null &&
                        dialogContext.mounted) {
                      final confirm = await showDialog<bool>(
                        context: dialogContext,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm model change'),
                          content: Text(
                            result.confirmMessage ?? 'This model may cost more. Use it as the default?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Use model'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final modelResult = await widget.repository.save(
                          currentBot,
                          model: pickedModel.modelId,
                          provider: pickedModel.providerId,
                          confirmExpensiveModel: true,
                        );
                        result = BotModeSaveResult(
                          {...result.applied, ...modelResult.applied},
                          conflict: result.conflict || modelResult.conflict,
                          confirmRequired: modelResult.confirmRequired,
                        );
                      }
                    }
                    if (result.succeeded) {
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      await _load();
                    } else {
                      if (result.conflict ||
                          result.applied.values.any((value) => value)) {
                        final fresh = await widget.repository.load();
                        final matches = [
                          ...fresh.bots,
                          ...fresh.availableProfiles,
                        ].where((candidate) => candidate.name == bot.name);
                        if (matches.isNotEmpty) currentBot = matches.first;
                      }
                      update(() {
                        failed = result.failedSections;
                        conflict = result.conflict;
                      });
                    }
                  } on Object {
                    update(() => failed = ['connection']);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      title.dispose();
      summary.dispose();
      description.dispose();
      soul.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final roster = _roster;
    final ready = roster != null && roster.supported && _error == null;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return SettingsScaffold(
      title: 'Bots',
      subtitle: mac && ready ? '${roster.bots.length} bots' : null,
      previousTitle: null,
      search: ready && roster.bots.isNotEmpty
          ? SettingsSearch(
              query: _query,
              hint: 'Search bots',
              onChanged: (value) => setState(() => _query = value),
            )
          : null,
      actions: [
        SettingsBarAction(
          label: 'Refresh',
          icon: AppIcons.refresh,
          onPressed: _refresh,
        ),
        SettingsBarAction(
          label: 'Create bot',
          icon: AppIcons.add,
          onPressed: ready ? _create : null,
        ),
      ],
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _roster == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final roster = _roster;
    if (_error != null || roster == null) {
      return _notice('Could not load bots');
    }
    if (!roster.supported) {
      return _notice(
        'Bot Mode is not available',
        detail: 'This server needs a Bot Mode compatible update. Chat and Messaging are still available.',
      );
    }
    final query = _query.toLowerCase();
    bool matches(BotModeBot bot) =>
        '${bot.title} ${bot.name} ${bot.description}'.toLowerCase().contains(
          query,
        );
    final bots = roster.bots.where(matches).toList();
    final available = roster.availableProfiles.where(matches).toList();
    final editStyle = platformChromeOf(context) == PlatformChrome.macos
        ? macToolbarButtonStyle(context)
        : null;
    final metrics = GroupedMetrics.of(context);
    return GroupedListView(
      children: [
        if (roster.bots.isEmpty)
          const StateMessage(
            icon: AppIcons.bot,
            title: 'No bots yet',
            detail: 'Create a specialist or add a profile you already use.',
          )
        else if (bots.isEmpty)
          const StateMessage(
            title: 'No matching bots',
            detail: 'Try another name or profile.',
          )
        else
          GroupedSection(
            header: 'Bots',
            dividerIndent: metrics.indentAfterTile,
            footer:
                'Each bot has its own profile, instructions and conversation.',
            children: [for (final bot in bots) _botRow(bot, editStyle)],
          ),
        if (available.isNotEmpty)
          GroupedSection(
            header: 'Add an existing profile',
            dividerIndent: metrics.indentAfterTile,
            footer: 'Profiles on this server that are not bots yet.',
            children: [for (final profile in available) _profileRow(profile)],
          ),
        if (widget.groups != null && widget.onOpenGroup != null)
          GroupRoomsPanel(
            key: _groupsPanel,
            repository: widget.groups!,
            bots: roster.bots,
            onOpen: widget.onOpenGroup!,
          ),
      ],
    );
  }

  Widget _botRow(BotModeBot bot, ButtonStyle? editStyle) {
    final rawSummary = bot.metadata['description'];
    final summary = rawSummary is String ? rawSummary : bot.description;
    final preview = bot.preview ?? '';
    return GroupedRow(
      leading: _initialTile(bot),
      title: bot.title,
      subtitle: summary.isNotEmpty
          ? summary
          : preview.isNotEmpty
          ? preview
          : null,
      caption: [bot.name, ?bot.model].join(' · '),
      onTap: widget.onOpen == null ? null : () => widget.onOpen!(bot),
      trailing: NamedIconButton(
        label: 'Edit bot',
        icon: AppIcons.more,
        visualDensity: VisualDensity.compact,
        style: editStyle,
        onPressed: () => _edit(bot),
      ),
    );
  }

  Widget _profileRow(BotModeBot profile) => GroupedRow(
    leading: _initialTile(profile),
    title: profile.title,
    subtitle: profile.title == profile.name ? null : profile.name,
    trailing: InstallButton(
      label: 'Add',
      installing: _adding.contains(profile.name),
      onPressed: () => _add(profile),
    ),
  );

  Widget _initialTile(BotModeBot bot) => GroupedTile(
    child: ExcludeSemantics(
      child: Text(bot.title.characters.firstOrNull?.toUpperCase() ?? '?'),
    ),
  );

  Widget _notice(String title, {String? detail}) => StateMessage(
    title: title,
    detail: detail,
    action: OutlinedButton(onPressed: _load, child: const Text('Retry')),
  );
}
