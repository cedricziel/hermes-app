import 'package:flutter/material.dart';

import '../../models/hermes_status.dart';
import '../../theme/app_icons.dart';
import '../../widgets/grouped_list.dart';

class ConnectionSummary extends StatelessWidget {
  const ConnectionSummary({
    super.key,
    required this.serverUrl,
    this.identityName,
    this.provider,
    this.status,
    this.loading = false,
    this.error,
  });

  final String serverUrl;
  final String? identityName;
  final String? provider;
  final HermesStatus? status;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GroupedSection(
        header: 'Connection',
        children: [
          GroupedRow(
            leading: const AppIcon(AppIcons.server),
            title: 'Server',
            subtitle: serverUrl,
            subtitleMaxLines: null,
          ),
          if (identityName != null)
            GroupedRow(
              leading: const AppIcon(AppIcons.person),
              title: identityName!,
              titleMaxLines: null,
              subtitle: 'via $provider',
              subtitleMaxLines: null,
            ),
        ],
      ),
      GroupedSection(
        header: 'Dashboard',
        children: [
          if (loading)
            const GroupedRow(
              title: 'Loading status',
              trailing: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            )
          else if (error != null)
            GroupedRow(
              leading: AppIcon(
                AppIcons.error,
                color: Theme.of(context).colorScheme.error,
              ),
              title: 'Could not load status',
              subtitle: error,
              subtitleMaxLines: null,
            )
          else if (status != null) ...[
            GroupedRow(
              leading: const AppIcon(AppIcons.checkCircle),
              title: 'Agent version',
              subtitle: status!.version ?? 'unknown',
              subtitleMaxLines: null,
            ),
            GroupedRow(
              leading: const AppIcon(AppIcons.shield),
              title: 'Auth gate',
              subtitle: status!.authRequired
                  ? 'Enabled (${status!.authProviders.join(', ')})'
                  : 'Disabled (loopback)',
              subtitleMaxLines: null,
            ),
          ],
        ],
      ),
    ],
  );
}
