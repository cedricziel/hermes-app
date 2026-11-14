import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../macos/menu_bar_extra/menu_bar_extra_settings.dart';
import '../../notifications/notification_settings.dart';
import '../../settings/theme_controller.dart';
import '../../spotlight/spotlight_settings.dart';
import '../../telemetry/breadcrumbs.dart';
import '../../voice/dictation_settings.dart';

/// The user settings.
List<SingleChildWidget> settingsProviders() => [
  ChangeNotifierProvider(create: (_) => ThemeController()..load()),
  ChangeNotifierProvider(create: (_) => NotificationSettings()..load()),
  ChangeNotifierProvider(create: (_) => DictationSettings()..load()),
  ChangeNotifierProvider(
    create: (context) =>
        SpotlightSettings(breadcrumbs: context.read<Breadcrumbs>())..load(),
  ),
  ChangeNotifierProvider(create: (_) => MenuBarExtraSettings()..load()),
];
