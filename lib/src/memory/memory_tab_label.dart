import '../../l10n/l10n.dart';
import 'memory_usage.dart';

/// The name of a memory file in the app's language.
extension MemoryTabLabel on MemoryTab {
  String localizedLabel(AppLocalizations l10n) => switch (this) {
    MemoryTab.aboutYou => l10n.memoryTabAboutYou,
    MemoryTab.agentNotes => l10n.memoryTabAgentNotes,
  };
}
