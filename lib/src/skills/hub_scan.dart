// What the server's security scan of a hub skill reports, apart from the
// repository that fetches it so widgets can show it.

/// What the server's security scan says may be done with a skill. Anything it
/// does not say in so many words counts as [block].
enum InstallPolicy { allow, ask, block }

class ScanFinding {
  const ScanFinding({
    required this.severity,
    required this.description,
    this.file = '',
    this.line,
  });

  final String severity;
  final String description;
  final String file;
  final int? line;
}

class HubScan {
  const HubScan({
    required this.identifier,
    required this.policy,
    this.verdict = '',
    this.summary = '',
    this.policyReason = '',
    this.findings = const [],
    this.severityCounts = const {},
  });

  /// What was scanned, so an install can be held to the scan of that very skill.
  final String identifier;
  final InstallPolicy policy;
  final String verdict;
  final String summary;
  final String policyReason;
  final List<ScanFinding> findings;
  final Map<String, int> severityCounts;
}
