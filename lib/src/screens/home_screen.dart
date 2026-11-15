import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../auth/auth_controller.dart';
import '../macos/mac_commands.dart';
import '../models/hermes_status.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/platform_refresh.dart';
import '../widgets/settings_scaffold.dart';
import 'widgets/connection_summary.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HermesStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _loadStatus();
  }

  Future<HermesStatus> _loadStatus() =>
      context.read<AuthController>().api!.fetchStatus();

  Future<void> _refresh() async {
    final future = _loadStatus();
    setState(() {
      _statusFuture = future;
    });
    await future.then<void>((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final identity = auth.identity;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final scaffold = SettingsScaffold(
      title: 'Connection',
      actions: [
        SettingsBarAction(
          key: const Key('connection-refresh'),
          label: context.l10n.screensRefreshAction,
          icon: AppIcons.refresh,
          shortcut: mac ? '⌘R' : null,
          onPressed: _refresh,
        ),
      ],
      body: PlatformRefresh(
        onRefresh: _refresh,
        child: GroupedListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FutureBuilder<HermesStatus>(
              future: _statusFuture,
              builder: (context, snapshot) => ConnectionSummary(
                serverUrl: auth.baseUrl ?? '',
                identityName: identity == null
                    ? null
                    : identity.displayName.isNotEmpty
                    ? identity.displayName
                    : identity.email.isNotEmpty
                    ? identity.email
                    : identity.userId,
                provider: identity?.provider,
                loading: snapshot.connectionState != ConnectionState.done,
                error: snapshot.hasError ? '${snapshot.error}' : null,
                status: snapshot.data,
              ),
            ),
            GroupedSection(
              children: [
                if (auth.status?.authRequired ?? false)
                  GroupedRow(title: 'Sign out', onTap: auth.signOut),
                GroupedRow(title: 'Change server', onTap: auth.changeServer),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mac) return scaffold;
    // View > Reload owns ⌘R.
    return MacCommandScope(
      commands: {
        MacCommand.reload: MacCommandHandler(() => unawaited(_refresh())),
      },
      child: scaffold,
    );
  }
}
