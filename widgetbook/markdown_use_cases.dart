import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:hermes_app/src/chat/widgets/chat_text_message.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/type_scale.dart';
import 'package:hermes_app/src/widgets/app_markdown_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';
import 'package:hermes_app/src/widgets/markdown_task_box.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

// Everything here is invented.

const _plain =
    'The soil probe in plot A reported 14.2 percent moisture at six this '
    'morning, which is inside the range the greenhouse plan allows. Nothing '
    'needs watering before the evening check.';

const _headings = '''# Heading one
## Heading two
### Heading three
#### Heading four
##### Heading five
###### Heading six

Body text under the headings.''';

const _lists = '''Things to check:

- Probe battery in plot A
- Irrigation valve 3
  - Seal
  - Pressure
- Weather feed

Steps:

1. Read the probes
2. Compare with the plan
3. Report the drift''';

const _tasks = '''Evening round:

- [x] Read the probes
- [x] Close the vents
- [ ] Refill the tank
- [ ] Log the readings''';

const _inlineCode =
    'Set `moisture_target` to `14.5` and run `greenhouse sync --dry-run` '
    'before the next check.';

const _shortCode = '''Here is the helper:

```python
def moisture(readings):
    # the mean, in percent
    return sum(readings) / len(readings)
```

It returns the mean.''';

String _readings(int count) => List.generate(
  count,
  (i) => 'reading_${i + 1} = probe.read(plot="A", index=${i + 1})  # fixture',
).join('\n');

final _longCode =
    '''The full log:

```python
${_readings(40)}
```

That was every reading.''';

// One block over `kHighlightMaxBlock` (8000 characters) with every line far
// under `kHighlightMaxLine`, so only the block limit decides.
final _overLimitCode =
    '''The raw dump is too long to colour, so it is plain monospace:

```python
${_readings(150)}
```

A short block after it:

```json
{"plot": "A", "valid": true}
```''';

const _links = '''# Greenhouse report

The [irrigation plan](https://example.com/plan) was updated. See also
[the sensor notes](https://example.com/sensors) and the `moisture_target`
setting.

## Checks

### Probes

#### Battery

##### Seal

###### Pressure

---

Text after the rule.''';

class _Sample {
  const _Sample(this.name, this.text, [this.note, this.chatOnly = false]);
  final String name;
  final String text;
  final String? note;

  /// The note describes the chat host (`FlyerMaterialScope`), not other sites.
  final bool chatOnly;
}

final _samples = <_Sample>[
  const _Sample('Plain text', _plain),
  const _Sample(
    'Headings h1 to h6',
    _headings,
    'Shows the 26/22/19/17/15/14 heading scale.',
  ),
  const _Sample('Bullet and numbered lists', _lists),
  const _Sample(
    'Task lists',
    _tasks,
    "Shows the package's Material checkbox in chat task lists, not the app's "
        'own checkbox.',
    true,
  ),
  const _Sample(
    'Inline code',
    _inlineCode,
    'Shows the stock inline-code colours of the package.',
  ),
  const _Sample('Short code block', _shortCode),
  _Sample('Long code block', _longCode),
  _Sample(
    'Code over the colouring limit (plain)',
    _overLimitCode,
    'The first block is over kHighlightMaxBlock (8000 characters) and is '
        'plain; the short block after it is coloured.',
    false,
  ),
];

/// [child] under a one-line caption (the catalog has no description field).
/// A [known] caption names an inconsistency the case shows; otherwise it only
/// describes the case.
Widget _noted(String? note, Widget child, {bool known = true}) => note == null
    ? child
    : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Builder(
              builder: (context) => Text(
                known ? 'Known: $note' : note,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      );

/// The text size at the largest setting of the viewport's platform: about 3.1x
/// on iPhone and 2x on Mac.
double _largest(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.macOS ? 2 : 3.1;

Widget _scaled(BuildContext context, double scale, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
  child: child,
);

TextStyle _body(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onSurface,
  fontSize: messageFontSizeFor(Theme.of(context).platform),
  height: 1.5,
);

/// The package's task checkbox is a `material_ui` one and asserts without a
/// `material_ui` `Material` above it (the catalog's `Scaffold` is not one).
Widget _onMaterial(Widget child) =>
    mui.Material(type: mui.MaterialType.transparency, child: child);

/// A `BoundedMarkdown` the way its non-chat call sites build it (see
/// `SkillMarkdownPanel`): no chat style, read-only task and radio boxes.
Widget _bounded(BuildContext context, String text) => frame(
  AppMarkdownTheme(
    child: BoundedMarkdown(
      text,
      onLinkTap: (_, _) {},
      checkboxBuilder: readOnlyTaskBox,
      radioOptionBuilder: readOnlyRadioOption,
    ),
  ),
  maxWidth: 560,
);

Widget _chatText(BuildContext context, String text, {bool sentByMe = false}) {
  final scheme = Theme.of(context).colorScheme;
  return _onMaterial(
    frame(
      ChatTextMessage(
        message: TextMessage(id: 'm1', authorId: 'u1', text: text),
        textStyle: _body(context),
        linksDecoration: TextDecoration.underline,
        onLinkTap: (_, _) {},
        backgroundColor: sentByMe
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(sentByMe ? kHermesRadius : 0),
        padding: sentByMe
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : EdgeInsets.zero,
      ),
      maxWidth: 560,
    ),
  );
}

List<WidgetbookUseCase> _cases(
  Widget Function(BuildContext, String) build, {
  required bool chat,
}) => [
  for (final s in _samples)
    WidgetbookUseCase(
      name: s.name,
      builder: (context) => _noted(
        chat || !s.chatOnly ? s.note : null,
        build(context, s.text),
        known: s.name != 'Code over the colouring limit (plain)',
      ),
    ),
  WidgetbookUseCase(
    name: 'Largest text',
    builder: (context) => _noted(
      'about 3.1x text on iPhone and 2x on Mac; the 26/22/19/17/15/14 '
      'heading scale${chat ? " and the package's Material task checkbox" : ""}.',
      _scaled(
        context,
        _largest(context),
        build(context, '$_headings\n\n$_tasks\n\n$_inlineCode\n\n$_shortCode'),
      ),
    ),
  ),
];

WidgetbookNode markdownNode() => WidgetbookFolder(
  name: 'Markdown',
  children: [
    WidgetbookComponent(
      name: 'BoundedMarkdown',
      useCases: _cases(_bounded, chat: false),
    ),
    WidgetbookComponent(
      name: 'ChatTextMessage',
      useCases: [
        ..._cases(_chatText, chat: true),
        WidgetbookUseCase(
          name: 'Sent by me (bubble)',
          builder: (context) => _noted(
            'the stock inline-code colours of the package.',
            _chatText(
              context,
              'Please check the [irrigation plan](https://example.com/plan) '
              'and set `moisture_target` to 14.5.\n\n- plot A\n- plot B',
              sentByMe: true,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'AppMarkdownTheme',
      useCases: [
        WidgetbookUseCase(
          name: 'Headings, links and inline code',
          builder: (context) => _noted(
            "The theme's tokens in action: on-surface headings, the app's link "
            'colour and the outline-colour rule. Known: the 26/22/19/17/15/14 '
            'heading scale and the stock inline-code colours of the package.',
            _bounded(context, _links),
            known: false,
          ),
        ),
      ],
    ),
  ],
);
