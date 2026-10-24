import 'package:flutter/material.dart';

import '../../mcp/mcp_banner.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../memory_provider.dart';

/// Where the profile's memory lives, and the way to start over. [provider] is
/// null until it is read or when [providerFailed]; Reset stays usable either
/// way. [onReset] asks which files to erase.
class MemoryStorageSection extends StatelessWidget {
  const MemoryStorageSection({
    super.key,
    required this.provider,
    required this.onOpenProviders,
    required this.onRetry,
    required this.onReset,
    this.providerFailed = false,
    this.resetting = false,
    this.notice,
  });

  final MemoryProviderStatus? provider;
  final bool providerFailed;
  final bool resetting;
  final MemoryNotice? notice;
  final VoidCallback onOpenProviders, onRetry, onReset;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = provider;
    final notice = this.notice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status?.state == MemoryProviderState.missing)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: McpBanner(
              tone: McpTone.error,
              icon: AppIcons.error,
              title: 'Memory provider is missing',
              detail:
                  '${status!.name} is no longer installed on the server. '
                  'Hermes falls back to the built-in files until you pick '
                  'another provider.',
            ),
          ),
        GroupedSection(
          header: 'Storage',
          children: [
            if (status != null)
              _providerRow(status)
            else if (providerFailed)
              GroupedRow(
                title: "Couldn't read the memory provider",
                value: 'Retry',
                onTap: onRetry,
              )
            else
              const GroupedRow(title: 'Memory provider', value: 'Reading…'),
          ],
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: McpBanner(
              tone: switch (notice.tone) {
                MemoryNoticeTone.success => McpTone.success,
                MemoryNoticeTone.warning => McpTone.warning,
                MemoryNoticeTone.error => McpTone.error,
              },
              icon: notice.tone == MemoryNoticeTone.success
                  ? AppIcons.checkCircle
                  : AppIcons.error,
              title: notice.text,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: OutlinedButton(
            onPressed: resetting ? null : onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('Reset memory…'),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            6,
            metrics.rowPadding,
            24,
          ),
          child: Text(
            "Erases the files on the server. Open chats keep what they "
            "started with. This can't be undone.",
            style: TextStyle(
              fontSize: metrics.footerSize,
              color: context.hermesColors.subtleText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _providerRow(MemoryProviderStatus status) {
    final builtin = status.state == MemoryProviderState.builtin;
    return GroupedRow(
      title: 'Memory provider',
      value: builtin ? null : status.name,
      subtitle: builtin
          ? 'Built-in · MEMORY.md and USER.md'
          : status.description,
      subtitleMaxLines: 2,
      warning: switch (status.state) {
        MemoryProviderState.needsConfig => 'Needs setup on the server',
        MemoryProviderState.unavailable => 'Not available on the server',
        _ => null,
      },
      onTap: onOpenProviders,
    );
  }
}
