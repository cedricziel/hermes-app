import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app/providers/deep_link_providers.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/deep_links/deep_link_listener.dart';
import 'package:hermes_app/src/deep_links/deep_link_target.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/telemetry/telemetry_config.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<DeepLinks?> mount(
    WidgetTester tester,
    TargetPlatform platform, {
    required List<String> launchArguments,
    required Stream<Uri> platformLinks,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    final telemetry = await Telemetry.initialize(
      TelemetryConfig.fromEnvironment(),
    );
    late DeepLinks? deepLinks;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.none),
          ...deepLinkProviders(
            telemetry,
            launchArguments: launchArguments,
            platformLinks: platformLinks,
          ),
        ],
        child: Builder(
          builder: (context) {
            deepLinks = context.read<DeepLinks?>();
            return const SizedBox();
          },
        ),
      ),
    );
    // The provider read the platform while mounting.
    debugDefaultTargetPlatformOverride = null;
    return deepLinks;
  }

  testWidgets('on Linux a launch link and a later one reach DeepLinks', (
    tester,
  ) async {
    final live = StreamController<Uri>.broadcast(sync: true);
    addTearDown(live.close);
    final deepLinks = await mount(
      tester,
      TargetPlatform.linux,
      launchArguments: ['hermes://new?prompt=hi'],
      platformLinks: live.stream,
    );
    await tester.pump();

    expect(deepLinks, isNotNull);
    final first = deepLinks!.take();
    expect(first?.target, const NewChat(prompt: 'hi'));
    expect(first?.cold, isTrue);
    expect(deepLinks.take(), isNull);

    live.add(Uri.parse('hermes://kanban'));
    await tester.pump();
    expect(deepLinks.take()?.target, const OpenKanban());
  });

  testWidgets('on Windows there is no deep-link source', (tester) async {
    final live = StreamController<Uri>.broadcast(sync: true);
    addTearDown(live.close);
    final deepLinks = await mount(
      tester,
      TargetPlatform.windows,
      launchArguments: ['hermes://kanban'],
      platformLinks: live.stream,
    );

    expect(deepLinks, isNull);
    expect(live.hasListener, isFalse);
  });

  test('main passes its arguments on as the launch arguments', () {
    expect(
      File('lib/main.dart').readAsStringSync(),
      contains('deepLinkProviders(telemetry, launchArguments: args)'),
    );
  });
}
