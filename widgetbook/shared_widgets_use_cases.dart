import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/command_row.dart';
import 'package:hermes_app/src/widgets/destructive_tint_button.dart';
import 'package:hermes_app/src/widgets/grouped_action_row.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/loading_skeleton.dart';
import 'package:hermes_app/src/widgets/output_lines_tile.dart';
import 'package:hermes_app/src/widgets/whats_the_difference_link.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

Widget _largest(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
  child: child,
);

Widget _reduceMotion(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child,
);

Widget _button({
  String label = 'Stop agent',
  bool disabled = false,
  bool busy = false,
  bool icon = true,
}) => Align(
  alignment: Alignment.centerRight,
  child: DestructiveTintButton(
    label: label,
    icon: icon ? AppIcons.stop : null,
    busy: busy,
    onPressed: disabled
        ? null
        : () => Future<void>.delayed(const Duration(milliseconds: 600)),
  ),
);

const _subtitle = 'Last run 2 days ago, 3 skills unused';
const _longSubtitle =
    'Looks at every skill in this profile and lists the ones that were '
    'never used, so you can decide which to keep, archive or remove.';

Widget _subtitleRow({
  String subtitle = _subtitle,
  GroupedActionStatus? status,
}) => frame(
  GroupedSection(
    header: 'Curator',
    children: [
      GroupedActionRow(
        title: 'Check skills',
        subtitle: subtitle,
        icon: AppIcons.refresh,
        onPressed: () {},
        status: status,
      ),
    ],
  ),
);

const _outputLines = [
  'Collecting hermes-agent',
  'Installing collected packages: hermes-agent',
  'Successfully installed hermes-agent-0.22.2',
];

Widget _output(List<String> lines, {bool open = false}) => frame(
  GroupedSection(
    children: [
      OutputLinesTile(label: 'Show output', lines: lines, initiallyOpen: open),
    ],
  ),
);

WidgetbookNode sharedWidgetsNode() => WidgetbookFolder(
  name: 'Shared widgets',
  children: [
    WidgetbookComponent(
      name: 'WhatsTheDifferenceLink',
      useCases: [
        ...onEachPlatform(
          'Link',
          (_) => frame(WhatsTheDifferenceLink(onTap: () {})),
        ),
        ...onEachPlatform(
          'Under a group footer',
          (context) => frame(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GroupedSection(
                  footer: context.l10n.toolsFooterBody,
                  children: [const GroupedRow(title: 'Sample row')],
                ),
                WhatsTheDifferenceFooter(onTap: () {}),
              ],
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) => _largest(
            context,
            frame(WhatsTheDifferenceLink(onTap: () {}), maxWidth: 320),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'DestructiveTintButton',
      useCases: [
        ...onEachPlatform('Idle', (_) => frame(_button())),
        WidgetbookUseCase(
          name: 'Without an icon',
          builder: (_) => frame(_button(icon: false, label: 'Restore')),
        ),
        ...onEachPlatform('Busy', (_) => frame(_button(busy: true))),
        ...onEachPlatform('Disabled', (_) => frame(_button(disabled: true))),
        WidgetbookUseCase(
          name: 'Long label',
          builder: (_) => frame(
            _button(label: 'Restore all 12 files from this checkpoint'),
            maxWidth: 260,
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) => _largest(
            context,
            frame(_button(label: 'Stop this running agent'), maxWidth: 320),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'CommandRow',
      useCases: [
        ...onEachPlatform(
          'Long command',
          (_) => frame(
            const CommandRow(
              command:
                  'curl -fsSL https://example.invalid/install.sh | '
                  'bash -s -- --upgrade --channel stable',
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) => _largest(
            context,
            frame(const CommandRow(command: 'hermes update --yes')),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'LoadingSkeleton',
      useCases: [
        WidgetbookUseCase(
          name: 'Default',
          builder: (_) => frame(const LoadingSkeleton(label: 'Loading logs')),
        ),
        WidgetbookUseCase(
          name: 'Reduce Motion',
          builder: (context) => _reduceMotion(
            context,
            frame(const LoadingSkeleton(label: 'Loading logs', lines: 5)),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'GroupedActionRow with subtitle',
      useCases: [
        ...onEachPlatform('Idle', (_) => _subtitleRow()),
        ...onEachPlatform(
          'Long subtitle',
          (_) => _subtitleRow(subtitle: _longSubtitle),
        ),
        WidgetbookUseCase(
          name: 'Working',
          builder: (context) => _reduceMotion(
            context,
            _subtitleRow(
              status: const GroupedActionStatus(
                phase: GroupedActionPhase.working,
                text: 'Checking…',
              ),
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Done',
          builder: (_) => _subtitleRow(
            status: const GroupedActionStatus(
              phase: GroupedActionPhase.done,
              text: 'Checked',
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Failed with buttons',
          builder: (_) => _subtitleRow(
            status: GroupedActionStatus(
              phase: GroupedActionPhase.failed,
              text: "The check didn't finish",
              buttons: [
                GroupedActionButton(label: 'Try again', onPressed: () {}),
              ],
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Warning',
          builder: (_) => _subtitleRow(
            status: const GroupedActionStatus(
              phase: GroupedActionPhase.warning,
              text: "The check hasn't answered yet",
            ),
          ),
        ),
        WidgetbookUseCase(
          name: 'Largest text, long subtitle',
          builder: (context) =>
              _largest(context, _subtitleRow(subtitle: _longSubtitle)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'OutputLinesTile',
      useCases: [
        ...onEachPlatform('Collapsed', (_) => _output(_outputLines)),
        ...onEachPlatform('Open', (_) => _output(_outputLines, open: true)),
        WidgetbookUseCase(
          name: 'Long lines',
          builder: (_) => _output([
            'error: could not resolve https://example.invalid/a/very/long/path/'
                'that/does/not/break/anywhere/at/all/index.json',
            ..._outputLines,
          ], open: true),
        ),
        WidgetbookUseCase(
          name: 'Empty',
          builder: (_) => _output(const [], open: true),
        ),
        WidgetbookUseCase(
          name: 'Largest text',
          builder: (context) =>
              _largest(context, _output(_outputLines, open: true)),
        ),
      ],
    ),
  ],
);
