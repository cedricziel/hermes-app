import 'chat_models.dart';

/// Placeholder content standing in for Hermes Agent's real session API, so
/// this design preview can be reviewed and iterated on before that wiring
/// exists. Replace with `HermesApiClient` session/message calls once the
/// dashboard exposes them.
List<ChatThread> buildMockThreads() {
  final now = DateTime.now();
  return [
    ChatThread(
      id: 't1',
      title: 'Summarize last night\'s run logs',
      updatedAt: now.subtract(const Duration(minutes: 4)),
      messages: [
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: 'Can you look at the last run and tell me why it failed around 02:14?',
          createdAt: now.subtract(const Duration(minutes: 6)),
        ),
        ChatMessage(
          id: 'm2',
          role: ChatRole.assistant,
          content:
              'I pulled the log window around 02:14 and ran it through the '
              'error-pattern search.\n\n'
              'The job hit a `ConnectionResetError` while streaming the '
              'checkpoint upload — the retry policy gave up after 3 '
              'attempts because the backoff cap was set below the '
              'observed network latency.\n\n'
              '```python\n'
              'RETRY_BACKOFF_CAP_S = 8  # too low for this host\n'
              '```\n\n'
              'Bumping that to 30s should cover it. Want me to open a PR?',
          createdAt: now.subtract(const Duration(minutes: 4)),
          toolCalls: const [
            ToolCall(
              name: 'search_logs',
              summary: 'run_2024_08_11 · window 02:10–02:20',
            ),
          ],
        ),
      ],
    ),
    ChatThread(
      id: 't2',
      title: 'Draft release notes for v0.9',
      updatedAt: now.subtract(const Duration(hours: 3)),
      messages: [
        ChatMessage(
          id: 'm3',
          role: ChatRole.user,
          content: 'Draft release notes from the merged PRs this week.',
          createdAt: now.subtract(const Duration(hours: 3, minutes: 2)),
        ),
        ChatMessage(
          id: 'm4',
          role: ChatRole.assistant,
          content:
              'Here\'s a first pass:\n\n'
              '- Native OIDC + password sign-in via the RFC 8252 loopback flow\n'
              '- Automatic token refresh on 401\n'
              '- New status screen for the connected dashboard\n\n'
              'Let me know if you want this split by area instead.',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
      ],
    ),
    ChatThread(
      id: 't3',
      title: 'Explain the PKCE flow to a new hire',
      updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
      messages: [
        ChatMessage(
          id: 'm5',
          role: ChatRole.user,
          content:
              'One of our new engineers is confused about why the '
              'password login also opens a browser. Can you explain it '
              'simply?',
          createdAt: now.subtract(
            const Duration(days: 1, hours: 2, minutes: 1),
          ),
        ),
        ChatMessage(
          id: 'm6',
          role: ChatRole.assistant,
          content:
              'Sure — both providers share one native flow so the app '
              'only has to implement RFC 8252 once. Routing the password '
              'form through the system browser also means the OS '
              'password manager can autofill it, which a native text '
              'field can\'t offer.',
          createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        ),
      ],
    ),
  ];
}

const List<String> kStarterPrompts = [
  'What changed on the server in the last 24 hours?',
  'Summarize open issues tagged "auth"',
  'Draft a status update for the team',
  'Explain what this agent can do',
];

/// A canned assistant reply used to demonstrate the thinking → streaming →
/// sent lifecycle in the UI. Real streaming will replace this with tokens
/// read off the session's SSE/WebSocket stream.
String buildMockReply(String userMessage) {
  return 'Got it — I don\'t have a live session to work from yet, so this '
      'is a placeholder reply standing in for "$userMessage". Once the '
      'dashboard\'s session API is wired in, this response will stream in '
      'from Hermes Agent instead.';
}
