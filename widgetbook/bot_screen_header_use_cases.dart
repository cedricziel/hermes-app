import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_header.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_viewer_view.dart'
    show BotScreenViewerPresentation;
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

/// The header on the viewer's black, in the dark theme the viewer uses, at
/// text scale [scale].
Widget _header({
  required double scale,
  String profile = 'research',
  String? control = 'Hermes is in control',
  bool inControl = false,
  BotScreenHeaderAction? action,
  BotScreenViewerPresentation presentation = BotScreenViewerPresentation.page,
}) => Builder(
  builder: (context) => Theme(
    data: buildHermesDarkTheme(platform: Theme.of(context).platform),
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: fill(
          Material(
            color: Colors.black,
            child: SafeArea(
              child: BotScreenViewerHeader(
                profile: profile,
                control: control,
                inControl: inControl,
                action: action,
                presentation: presentation,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

WidgetbookNode botScreenViewerHeaderNode() {
  const takeOver = BotScreenHeaderAction(label: 'Take over', onPressed: _noop);
  const handBack = BotScreenHeaderAction(label: 'Hand Back', onPressed: _noop);
  const busy = BotScreenHeaderAction(label: 'Taking over…');
  final cases = <(String, Widget Function(double))>[
    ('Watching, Take over', (s) => _header(scale: s, action: takeOver)),
    (
      'In control, Hand Back, over the window',
      (s) => _header(
        scale: s,
        control: "You're in control",
        inControl: true,
        action: handBack,
        presentation: BotScreenViewerPresentation.overlay,
      ),
    ),
    ('Taking over, button off', (s) => _header(scale: s, action: busy)),
    (
      'Control line, no action',
      (s) => _header(scale: s, control: 'Someone else is in control'),
    ),
    ('No control line, no action', (s) => _header(scale: s, control: null)),
    (
      'No control line, over the window',
      (s) => _header(
        scale: s,
        control: null,
        presentation: BotScreenViewerPresentation.overlay,
      ),
    ),
    (
      'Long profile name, Take over',
      (s) => _header(
        scale: s,
        profile: 'quarterly-research-assistant',
        action: takeOver,
      ),
    ),
  ];
  return WidgetbookComponent(
    name: 'Bot screen viewer header',
    useCases: [
      for (final (name, build) in cases)
        for (final scale in const [1.0, 2.0])
          ...onEachPlatform(
            '$name, ${scale == 1 ? '1x' : '2x'} text',
            (_) => build(scale),
          ),
    ],
  );
}

void _noop() {}
