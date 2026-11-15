import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/app_banner.dart';
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
  AppBannerTone tone,
  AppIconSet? icon,
) => [
  _case(
    label,
    () => AppBanner(
      tone: tone,
      icon: icon,
      title: '$label note',
      detail: _detail,
    ),
  ),
  _case(
    '$label with action',
    () => AppBanner(
      tone: tone,
      icon: icon,
      title: '$label note',
      detail: _detail,
      action: _action(),
    ),
  ),
  _case(
    '$label, title only',
    () => AppBanner(tone: tone, icon: icon, title: '$label note'),
  ),
];

WidgetbookFolder appBannerNode() => WidgetbookFolder(
  name: 'AppBanner',
  children: [
    WidgetbookComponent(
      name: 'AppBanner',
      useCases: [
        ..._tone('Success', AppBannerTone.success, null),
        ..._tone('Warning', AppBannerTone.warning, null),
        ..._tone('Error', AppBannerTone.error, null),
        ..._tone('Neutral', AppBannerTone.neutral, null),
        WidgetbookUseCase(
          name: 'Largest text, with action',
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: frame(
              AppBanner(
                tone: AppBannerTone.neutral,
                title: 'You are offline',
                detail: _detail,
                action: _action(),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text (3x), long title, stacked action',
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3)),
            child: frame(
              AppBanner(
                tone: AppBannerTone.warning,
                title: "Couldn't confirm the save",
                detail: 'It may have gone through. Your text is still here.',
                action: TextButton(
                  onPressed: () {},
                  child: const Text('Check'),
                ),
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'German, stacked action',
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('de'),
            child: frame(
              AppBanner(
                tone: AppBannerTone.warning,
                title: 'Die Speicherung konnte nicht bestätigt werden',
                detail:
                    'Sie ist möglicherweise durchgegangen. Ihr Text ist noch '
                    'hier.',
                action: TextButton(
                  onPressed: () {},
                  child: const Text('Erneut prüfen'),
                ),
              ),
            ),
          ),
        ),
        // The outline shows the action's own box: 44 pt, 48 dp, 28 pt.
        ...onEachPlatform(
          'Action target',
          (_) => frame(
            AppBanner(
              tone: AppBannerTone.error,
              title: "Couldn't save",
              detail: 'Nothing was changed on the server.',
              action: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.pinkAccent),
                ),
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Try again'),
                ),
              ),
            ),
          ),
        ),
        _case(
          'Custom icon',
          () => const AppBanner(
            tone: AppBannerTone.warning,
            icon: AppIcons.lock,
            title: 'Sign-in needed',
            detail: 'Approve access in your browser.',
          ),
        ),
      ],
    ),
  ],
);
