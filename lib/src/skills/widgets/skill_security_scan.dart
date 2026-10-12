import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../hermes_skills_hub_repository.dart';

class SkillSecurityScan extends StatelessWidget {
  const SkillSecurityScan({
    super.key,
    this.scan,
    this.failed = false,
    required this.onRetry,
  });
  final HubScan? scan;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final result = scan;
    final theme = Theme.of(context);
    final metrics = GroupedMetrics.of(context);
    if (failed) {
      return GroupedSection(
        header: 'Security scan',
        children: [
          const GroupedRow(
            title: 'Could not run the security scan.',
            chevron: false,
          ),
          GroupedRow(title: 'Retry', chevron: false, onTap: onRetry),
        ],
      );
    }
    if (result == null) {
      return const GroupedSection(
        header: 'Security scan',
        children: [
          GroupedRow(
            title: 'Running the security scan…',
            chevron: false,
            trailing: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ),
        ],
      );
    }
    final color = switch (result.policy) {
      InstallPolicy.allow => theme.colorScheme.primary,
      InstallPolicy.ask => context.hermesColors.warning,
      InstallPolicy.block => theme.colorScheme.error,
    };
    return GroupedSection(
      header: 'Security scan',
      children: [
        Padding(
          padding: EdgeInsets.all(metrics.rowPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (result.policy) {
                  InstallPolicy.allow => 'Passed',
                  InstallPolicy.ask => 'Caution: confirmation required',
                  InstallPolicy.block => 'Blocked',
                },
                key: const ValueKey('scan-verdict'),
                style: TextStyle(
                  fontSize: metrics.titleSize,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (result.summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(result.summary),
              ],
              if (result.severityCounts.values.any((count) => count > 0)) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final entry in result.severityCounts.entries)
                      if (entry.value > 0) Text('${entry.value} ${entry.key}'),
                  ],
                ),
              ],
              if (result.policy == InstallPolicy.block &&
                  result.policyReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(result.policyReason, style: TextStyle(color: color)),
              ],
              for (final finding in result.findings) ...[
                const Divider(height: 20),
                SkillScanFinding(finding),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SkillScanFinding extends StatelessWidget {
  const SkillScanFinding(this.finding, {super.key});

  final ScanFinding finding;

  @override
  Widget build(BuildContext context) {
    final where = [
      if (finding.file.isNotEmpty) finding.file,
      if (finding.line != null) '${finding.line}',
    ].join(':');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${finding.severity.toUpperCase()}  ${finding.description}'),
          if (where.isNotEmpty)
            Text(
              where,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
        ],
      ),
    );
  }
}
