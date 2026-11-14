import 'package:flutter/material.dart' hide Banner;
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/banner.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _detail =
    'The list below may be out of date. Pull to refresh and try again.';

Widget _action() =>
    TextButton(onPressed: () {}, child: const Text('Try again'));

WidgetbookUseCase _case(String name, Widget Function() banner) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(banner()));

List<WidgetbookUseCase> _tone(
  String label,
  BannerTone tone,
  AppIconSet? icon,
) => [
  _case(
    label,
    () => Banner(tone: tone, icon: icon, title: '$label note', detail: _detail),
  ),
  _case(
    '$label with action',
    () => Banner(
      tone: tone,
      icon: icon,
      title: '$label note',
      detail: _detail,
      action: _action(),
    ),
  ),
  _case(
    '$label, title only',
    () => Banner(tone: tone, icon: icon, title: '$label note'),
  ),
];

WidgetbookFolder bannerNode() => WidgetbookFolder(
  name: 'Banner',
  children: [
    WidgetbookComponent(
      name: 'Banner',
      useCases: [
        ..._tone('Success', BannerTone.success, null),
        ..._tone('Warning', BannerTone.warning, null),
        ..._tone('Error', BannerTone.error, null),
        ..._tone('Neutral', BannerTone.neutral, null),
        _case(
          'Custom icon',
          () => const Banner(
            tone: BannerTone.warning,
            icon: AppIcons.lock,
            title: 'Sign-in needed',
            detail: 'Approve access in your browser.',
          ),
        ),
      ],
    ),
  ],
);
