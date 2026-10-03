import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';

/// Finds the [Icon] showing [icon] on whichever platform the test runs as.
Finder findAppIcon(AppIconSet icon) => find.byWidgetPredicate(
  (widget) =>
      widget is Icon &&
      (widget.icon == icon.material || widget.icon == icon.apple),
);
