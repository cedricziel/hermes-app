import 'package:flutter/material.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/widgets/schedule_filter_menu.dart';
import 'package:hermes_app/src/schedules/widgets/schedules_mac_toolbar.dart';
import 'package:widgetbook/widgetbook.dart';

/// Shown on macOS in either viewport, as these only appear in a Mac window.
Widget _mac(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: Material(child: child),
  ),
);

WidgetbookUseCase _use(String name, Widget Function() build) =>
    WidgetbookUseCase(name: name, builder: (_) => _mac(build()));

Widget _toolbar({required bool allProfiles}) {
  var all = allProfiles;
  return StatefulBuilder(
    builder: (context, setState) => Align(
      alignment: Alignment.topCenter,
      child: SchedulesMacToolbar(
        jobCount: all ? 4 : 2,
        allProfiles: all,
        onScopeChanged: (value) => setState(() => all = value),
        filterMenu: ScheduleFilterMenu(
          filter: ScheduleFilter.all,
          failingCount: 1,
          onChanged: (_) {},
        ),
        onRefresh: () {},
        onNew: () {},
      ),
    ),
  );
}

WidgetbookNode schedulesMacNode() => WidgetbookFolder(
  name: 'Schedules (macOS)',
  children: [
    WidgetbookComponent(
      name: 'SchedulesMacToolbar',
      useCases: [
        _use('This profile', () => _toolbar(allProfiles: false)),
        _use('All profiles', () => _toolbar(allProfiles: true)),
      ],
    ),
  ],
);
