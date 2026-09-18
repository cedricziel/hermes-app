import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../models/hermes_status.dart';

/// Landing screen once connected (and, if required, signed in). A minimal
/// status view — the jumping-off point for the real Hermes chat/session UI.
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

  Future<HermesStatus> _loadStatus() {
    final auth = context.read<AuthController>();
    return auth.api!.fetchStatus();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final identity = auth.identity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hermes'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'sign-out') auth.signOut();
              if (value == 'change-server') auth.changeServer();
            },
            itemBuilder: (context) => [
              if (auth.status?.authRequired ?? false)
                const PopupMenuItem(value: 'sign-out', child: Text('Sign out')),
              const PopupMenuItem(
                value: 'change-server',
                child: Text('Change server'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final future = _loadStatus();
          setState(() => _statusFuture = future);
          await future;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Server'),
                subtitle: Text(auth.baseUrl ?? ''),
              ),
            ),
            if (identity != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    identity.displayName.isNotEmpty
                        ? identity.displayName
                        : identity.email.isNotEmpty
                        ? identity.email
                        : identity.userId,
                  ),
                  subtitle: Text('via ${identity.provider}'),
                ),
              ),
            FutureBuilder<HermesStatus>(
              future: _statusFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('Could not load status'),
                      subtitle: Text('${snapshot.error}'),
                    ),
                  );
                }
                final status = snapshot.data!;
                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: const Text('Agent version'),
                        subtitle: Text(status.version ?? 'unknown'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.shield_outlined),
                        title: const Text('Auth gate'),
                        subtitle: Text(
                          status.authRequired
                              ? 'Enabled (${status.authProviders.join(', ')})'
                              : 'Disabled (loopback)',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
