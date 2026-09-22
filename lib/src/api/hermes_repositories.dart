import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../bots/hermes_bots_repository.dart';
import '../chat/hermes_chat_repository.dart';
import '../kanban/hermes_plugins_repository.dart';
import '../kanban/kanban_repository.dart';
import '../mcp/hermes_mcp_repository.dart';
import '../plugins/hermes_plugin_manager_repository.dart';
import '../profiles/hermes_profiles_repository.dart';
import '../schedules/hermes_cron_repository.dart';
import '../skills/hermes_skills_hub_repository.dart';
import '../skills/hermes_skills_repository.dart';
import 'hermes_api_client.dart';

/// The repositories of one signed-in API client. `main.dart` provides it
/// while signed in, so screens read it instead of building repositories.
class HermesRepositories {
  HermesRepositories(this.api)
    : chat = HermesChatRepository(api.raw),
      profiles = HermesProfilesRepository(api.raw),
      bots = HermesBotsRepository(api.raw),
      skills = HermesSkillsRepository(api.raw),
      skillsHub = HermesSkillsHubRepository(api.raw),
      pluginManager = HermesPluginManagerRepository(api.raw),
      plugins = HermesPluginsRepository(api.raw),
      mcp = HermesMcpRepository(api.raw),
      cron = HermesCronRepository(api.raw),
      kanban = KanbanRepository(api);

  final HermesApiClient api;
  final HermesChatRepository chat;
  final HermesProfilesRepository profiles;
  final HermesBotsRepository bots;
  final HermesSkillsRepository skills;
  final HermesSkillsHubRepository skillsHub;
  final HermesPluginManagerRepository pluginManager;
  final HermesPluginsRepository plugins;
  final HermesMcpRepository mcp;
  final HermesCronRepository cron;
  final KanbanRepository kanban;

  /// Keeps [previous] while the API client is the same one.
  static HermesRepositories? forAuth(
    AuthController auth,
    HermesRepositories? previous,
  ) {
    final api = auth.api;
    if (api == null) return null;
    if (identical(previous?.api, api)) return previous;
    return HermesRepositories(api);
  }

  /// The provided repositories, or null when signed out. A widget pumped
  /// without the provider (tests, the catalog) gets them built from the
  /// [AuthController] above it, if any.
  static HermesRepositories? maybeOf(BuildContext context) {
    try {
      final provided = Provider.of<HermesRepositories?>(context, listen: false);
      if (provided != null) return provided;
    } on ProviderNotFoundException {
      // Fall through to the AuthController.
    }
    try {
      return forAuth(context.read<AuthController>(), null);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Like [maybeOf], for screens that only open while signed in.
  static HermesRepositories of(BuildContext context) =>
      maybeOf(context) ??
      (throw StateError('HermesRepositories read while signed out'));
}
