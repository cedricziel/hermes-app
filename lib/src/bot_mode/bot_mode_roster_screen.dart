import 'package:flutter/material.dart';

import '../models/hermes_models_repository.dart';
import '../models/model_provider_option.dart';
import '../models/widgets/model_picker.dart';
import '../widgets/content_column.dart';
import '../widgets/state_message.dart';
import '../theme/app_icons.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

  Future<void> _addExisting() async {
    final choices = _roster?.availableProfiles ?? const <BotModeBot>[];
    if (choices.isEmpty) {
      _message('No other profiles are available');
      return;
    }
    final picked = await showModalBottomSheet<BotModeBot>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Add an existing profile')),
            for (final bot in choices)
              ListTile(
                title: Text(bot.title),
                subtitle: Text(bot.name),
                onTap: () => Navigator.pop(context, bot),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      final result = await widget.repository.save(picked, title: picked.title);
      if (!result.succeeded) throw StateError('Presentation was not saved');
      await _load();
    } on Object {
      if (mounted) {
        _message('Could not add this profile. Retry from the roster.');
      }
    }
  }

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
    final summary = TextEditingController(
      text: bot.metadata['description'] as String? ?? '',
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Bots'),
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
    ),
    body: _body(),
  );

  Widget _body() {
    if (_loading && _roster == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null) return _notice('Could not load bots', 'Retry', _load);
    final roster = _roster;
    if (roster == null) return _notice('Could not load bots', 'Retry', _load);
    if (!roster.supported) {
      return _notice(
        'This server needs a Bot Mode compatible update. Chat and Messaging are still available.',
        'Retry',
        _load,
      );
    }
    final bots = roster.bots
        .where(
          (bot) => '${bot.title} ${bot.name} ${bot.description}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    return ContentColumn(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
        children: [
          Text('Your specialists', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Each bot has its own profile, instructions and conversation.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Create bot'),
              ),
              OutlinedButton.icon(
                onPressed: _addExisting,
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('Add profile'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search specialists',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 28),
          Text(
            'BOTS  ${roster.bots.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          if (roster.bots.isEmpty)
            const StateMessage(
              icon: AppIcons.bot,
              title: 'No bots yet',
              detail: 'Create a specialist or add a profile you already use.',
            ),
          if (roster.bots.isNotEmpty && bots.isEmpty)
            const StateMessage(
              title: 'No matching bots',
              detail: 'Try another name or profile.',
            ),
          for (final bot in bots) ...[
            _botCard(bot, theme, muted),
            const SizedBox(height: 10),
          ],
          if (widget.groups != null && widget.onOpenGroup != null) ...[
            const SizedBox(height: 24),
            GroupRoomsPanel(
              repository: widget.groups!,
              bots: roster.bots,
              onOpen: widget.onOpenGroup!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _botCard(BotModeBot bot, ThemeData theme, Color muted) {
    final scheme = theme.colorScheme;
    final summary = bot.metadata['description'] as String? ?? bot.description;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => widget.onOpen?.call(bot),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundColor: scheme.onSurface,
                child: Text(
                  bot.title.characters.first.toUpperCase(),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bot.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [bot.name, ?bot.model].join('  ·  '),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        summary,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (bot.preview case final preview?
                        when preview.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        preview,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                tooltip: 'Edit bot',
                onPressed: () => _edit(bot),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(String message, String action, VoidCallback onPressed) =>
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(message)),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      );
}
