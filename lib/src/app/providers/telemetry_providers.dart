import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// The breadcrumb trail.
List<SingleChildWidget> telemetryProviders(Telemetry telemetry) => [
  Provider<Breadcrumbs>.value(value: telemetry.breadcrumbs()),
];
