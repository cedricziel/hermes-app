import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/mcp/hermes_mcp_repository.dart';
import 'package:hermes_app/src/mcp/mcp_servers_screen.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';

void main() {
  ThemeData themed(TargetPlatform platform, {bool dark = false}) =>
      (dark ? buildHermesDarkTheme() : buildHermesLightTheme()).copyWith(
        platform: platform,
      );

  Future<bool> mcpSwitchIsCupertino(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/mcp/servers',
        mcpServerListBody([
          mcpServerRow(name: 'grafana', url: 'https://mcp.grafana.com/mcp'),
        ]),
      );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: McpServersScreen(
          repository: HermesMcpRepository(server.client().raw),
          profiles: HermesProfilesRepository(server.client().raw),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final painter = find.descendant(
      of: find.byType(Switch),
      matching: find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter.runtimeType.toString() == "_SwitchPainter",
      ),
    );
    // The adaptive Switch is still a Switch; only its painter knows the look.
    return (tester.widget<CustomPaint>(painter.first).painter as dynamic)
            .isCupertino
        as bool;
  }

  testWidgets('iOS shows the Cupertino-style switch', (tester) async {
    expect(
      await mcpSwitchIsCupertino(tester, themed(TargetPlatform.iOS)),
      isTrue,
    );
  });

  testWidgets('macOS shows the Cupertino-style switch', (tester) async {
    expect(
      await mcpSwitchIsCupertino(tester, themed(TargetPlatform.macOS)),
      isTrue,
    );
  });

  testWidgets('Android keeps the Material switch', (tester) async {
    expect(
      await mcpSwitchIsCupertino(tester, themed(TargetPlatform.android)),
      isFalse,
    );
  });

  for (final dark in [false, true]) {
    test('Apple switch track follows the zinc primary (dark: $dark)', () {
      final theme = themed(TargetPlatform.iOS, dark: dark);
      final adapted = theme.getAdaptation<SwitchThemeData>()!.adapt(
        theme,
        const SwitchThemeData(),
      );
      expect(
        adapted.trackColor!.resolve({WidgetState.selected}),
        theme.colorScheme.primary,
      );
      expect(
        adapted.thumbColor!.resolve({WidgetState.selected}),
        theme.colorScheme.onPrimary,
      );
    });
  }

  test('other platforms keep the default switch theme', () {
    final theme = themed(TargetPlatform.android);
    const defaults = SwitchThemeData();
    expect(
      theme.getAdaptation<SwitchThemeData>()!.adapt(theme, defaults),
      same(defaults),
    );
  });
}
